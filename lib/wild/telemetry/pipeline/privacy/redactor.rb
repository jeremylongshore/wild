# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Privacy
        class Redactor
          def initialize(metadata_redactor: MetadataRedactor.new)
            @metadata_redactor = metadata_redactor
          end

          def redact_transcript(transcript, config: Wild.config.telemetry.pipeline)
            raise PrivacyError, "transcript must be a Transcript" unless transcript.is_a?(Models::Transcript)

            redacted_turns = transcript.turns.map { |turn| redact_turn(turn, config: config) }
            redacted_intents = transcript.intents.map { |intent| redact_intent(intent, config: config) }

            Models::Transcript.new(
              source_type: transcript.source_type,
              source_id: transcript.source_id,
              turns: redacted_turns,
              intents: redacted_intents,
              tool_references: transcript.tool_references,
              metadata: redact_metadata(transcript.metadata, config: config).merge(redacted: true),
              created_at: transcript.created_at
            )
          end

          def redact_turn(turn, config: Wild.config.telemetry.pipeline)
            raise PrivacyError, "turn must be a Turn" unless turn.is_a?(Models::Turn)

            redacted_content = redact_content(turn.content, config: config)
            redacted_metadata = redact_metadata(turn.metadata, config: config)

            Models::Turn.new(
              role: turn.role,
              content: redacted_content,
              timestamp: turn.timestamp,
              metadata: redacted_metadata
            )
          end

          # Redacts intents derived from turn content: #run_pipeline builds
          # Intent#description from the raw (pre-redaction) turn text so that
          # detection sees the real content, which means the description is a
          # secret carrier just like turn content and must be scrubbed here,
          # the single boundary where every exported field gets redacted
          # (f-l03-1, the intent-description leak follow-up).
          def redact_intent(intent, config: Wild.config.telemetry.pipeline)
            Models::Intent.new(
              description: redact_content(intent.description, config: config),
              confidence: intent.confidence,
              source_turn_index: intent.source_turn_index
            )
          end

          # Splits on the configured marker before applying any pattern so an
          # already-redacted segment is never re-scanned: a marker shaped like
          # an email or path (e.g. "<redacted@wild.local>") would otherwise
          # get matched and re-wrapped by a second #redact_content pass,
          # corrupting it. This makes redaction idempotent regardless of
          # marker shape (f-l03-1 item 7 follow-up).
          def redact_content(content, config: Wild.config.telemetry.pipeline)
            return content.to_s if content.to_s.strip.empty?

            marker = config.redaction_marker
            content.split(marker, -1).map { |segment| redact_segment(segment, config) }.join(marker)
          end

          # Scrubs turn/transcript metadata via Privacy::MetadataRedactor: a
          # key-aware, secrets-only, class-preserving, depth-and-cycle-bounded
          # pass distinct from #redact_content's content-oriented patterns.
          # See MetadataRedactor's class comment for the full rationale
          # (f-l03-1).
          def redact_metadata(metadata, config: Wild.config.telemetry.pipeline)
            @metadata_redactor.call(metadata, config)
          end

          private

          def redact_segment(segment, config)
            result = apply_built_in_patterns(segment, config)
            apply_custom_patterns(result, config)
          end

          def apply_built_in_patterns(content, config)
            marker = config.redaction_marker
            result = content
            result = redact_pattern(result, Privacy::ContentFilter::EMAIL_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::API_KEY_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::AWS_ACCESS_KEY_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::AWS_SECRET_KEY_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::GITHUB_TOKEN_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::BEARER_TOKEN_PATTERN, marker)
            result = redact_pattern(result, Privacy::ContentFilter::IP_PATTERN, marker)
            result = redact_file_contents(result, marker) if config.strip_file_contents
            result = redact_absolute_paths(result, marker) if config.strip_absolute_paths
            result
          end

          def apply_custom_patterns(content, config)
            config.custom_patterns.reduce(content) do |result, pattern|
              redact_pattern(result, pattern, config.redaction_marker)
            end
          end

          # A key-anchored pattern (built-in, e.g. ContentFilter::API_KEY_PATTERN,
          # or a custom pattern the caller wrote the same way) declares named
          # `prefix`/`suffix` captures so only the secret value is replaced,
          # leaving the key name and any surrounding quotes intact: redacting
          # `"api_key":"sk_live_..."` must yield `"api_key":"[REDACTED]"`, not
          # a blob that swallows the key name and breaks the JSON/hash shape
          # the adapter emitted (f-l03-2). Patterns without those captures
          # keep the original whole-match replacement.
          def redact_pattern(content, pattern, marker)
            if key_anchored?(pattern)
              content.gsub(pattern) { "#{Regexp.last_match(:prefix)}#{marker}#{Regexp.last_match(:suffix)}" }
            else
              content.gsub(pattern, marker)
            end
          end

          def key_anchored?(pattern)
            pattern.is_a?(Regexp) && pattern.names.include?("prefix") && pattern.names.include?("suffix")
          end

          def redact_file_contents(content, marker)
            content.gsub(Privacy::ContentFilter::FILE_CONTENT_PATTERN, "[#{marker}:file_content]")
          end

          def redact_absolute_paths(content, marker)
            content.gsub(Privacy::ContentFilter::ABSOLUTE_PATH_PATTERN, marker)
          end
        end
      end
    end
  end
end
