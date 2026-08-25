# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Privacy
        class Redactor
          def redact_transcript(transcript, config: Wild.config.telemetry.pipeline)
            raise PrivacyError, "transcript must be a Transcript" unless transcript.is_a?(Models::Transcript)

            redacted_turns = transcript.turns.map { |turn| redact_turn(turn, config: config) }

            Models::Transcript.new(
              source_type: transcript.source_type,
              source_id: transcript.source_id,
              turns: redacted_turns,
              intents: transcript.intents,
              tool_references: transcript.tool_references,
              metadata: transcript.metadata.merge(redacted: true),
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

          def redact_content(content, config: Wild.config.telemetry.pipeline)
            return content.to_s if content.to_s.strip.empty?

            result = content.dup
            result = apply_built_in_patterns(result, config)
            apply_custom_patterns(result, config)
          end

          # Recursively scrubs string values inside turn metadata (e.g. the raw
          # tool_input/tool_output hashes ClaudeCodeAdapter copies verbatim). Lives
          # here, not in the adapters, so every ingestion source is covered by the
          # same privacy boundary rather than requiring each adapter to redact for
          # itself. Keys are left untouched; only String leaves are scrubbed;
          # non-Hash/Array/String values (numbers, booleans, nil, symbols) pass
          # through unchanged.
          def redact_metadata(metadata, config: Wild.config.telemetry.pipeline)
            redact_metadata_value(metadata, config)
          end

          private

          def redact_metadata_value(value, config)
            case value
            when String
              redact_content(value, config: config)
            when Hash
              value.each_with_object({}) { |(k, v), h| h[k] = redact_metadata_value(v, config) }
            when Array
              value.map { |v| redact_metadata_value(v, config) }
            else
              value
            end
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

          def redact_pattern(content, pattern, marker)
            content.gsub(pattern, marker)
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
