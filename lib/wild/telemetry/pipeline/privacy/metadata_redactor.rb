# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Privacy
        # Recursively scrubs turn/transcript metadata (e.g. the raw
        # tool_input/tool_output hashes ClaudeCodeAdapter copies verbatim).
        # Split out of Redactor (f-l03-1 item 7 fix-up: keeps Redactor under
        # Metrics/ClassLength) but is still reached only through
        # Redactor#redact_metadata, the single privacy boundary every
        # ingestion adapter's output passes through on the way to export.
        #
        # Two redaction modes apply, in order:
        #   1. Key-aware: a Hash key matching SECRET_KEY_PATTERN (e.g.
        #      "api_key", "aws_secret", "Authorization") redacts its WHOLE
        #      value with the config marker, String or nested structure
        #      alike, so a secret can't survive by being nested one level
        #      deeper than a leaf scrubber would look.
        #   2. Leaf scrubbing: any other String (or Symbol, redacted as a
        #      String) is scrubbed with secrets-only patterns (API key, AWS
        #      key/secret, GitHub token, bearer token, custom patterns).
        #      Unlike Redactor#redact_content, this deliberately excludes the
        #      EMAIL/IP/ABSOLUTE_PATH/file-content patterns: metadata
        #      routinely carries structural values (MCP `method`, `tool_name`,
        #      a `git@` remote URL, a `file_path`) that those content-oriented
        #      patterns mangle, breaking downstream consumers like
        #      ToolExtractor.
        #
        # Hash keys, and non-String/Symbol/Hash/Array values (numbers,
        # booleans, nil), pass through untouched. The rebuilt Hash preserves
        # its original class (`ActiveSupport::HashWithIndifferentAccess`
        # included) so indifferent-access lookups keep working post-redaction.
        # Key strings themselves are never rewritten (a follow-up bead covers
        # key-name redaction).
        class MetadataRedactor
          SECRET_KEY_PATTERN = /api?key|secret|token|password|passwd|credential|authorization|bearer|privatekey/i

          # Recursion depth cap. Real tool_input/tool_output payloads are a
          # handful of levels deep; 64 is generous headroom while still
          # turning a malformed or adversarial payload into a PrivacyError
          # instead of a SystemStackError.
          MAX_DEPTH = 64

          def call(metadata, config)
            return metadata if metadata.nil?

            redact_value(metadata, config, 0, {}.compare_by_identity)
          end

          private

          def redact_value(value, config, depth, ancestors)
            raise depth_error if depth > MAX_DEPTH

            case value
            when Hash then redact_hash(value, config, depth, ancestors)
            when Array then redact_array(value, config, depth, ancestors)
            when String then redact_leaf(value, config)
            when Symbol then redact_leaf(value.to_s, config)
            else value
            end
          end

          def redact_hash(hash, config, depth, ancestors)
            with_cycle_guard(hash, ancestors) do
              hash.each_with_object(hash.class.new) do |(key, value), result|
                result[key] =
                  secret_key?(key) ? config.redaction_marker : redact_value(value, config, depth + 1, ancestors)
              end
            end
          end

          def redact_array(array, config, depth, ancestors)
            with_cycle_guard(array, ancestors) do
              array.map { |v| redact_value(v, config, depth + 1, ancestors) }
            end
          end

          def with_cycle_guard(object, ancestors)
            raise PrivacyError, "metadata contains a circular reference" if ancestors.key?(object)

            ancestors[object] = true
            yield
          ensure
            ancestors.delete(object)
          end

          def depth_error
            PrivacyError.new("metadata redaction exceeded max depth (#{MAX_DEPTH})")
          end

          def secret_key?(key)
            normalized = key.to_s.downcase.gsub(/[^a-z0-9]/, "")
            SECRET_KEY_PATTERN.match?(normalized)
          end

          def redact_leaf(content, config)
            return content if content.strip.empty?

            marker = config.redaction_marker
            result = content
            [
              ContentFilter::API_KEY_PATTERN,
              ContentFilter::AWS_ACCESS_KEY_PATTERN,
              ContentFilter::AWS_SECRET_KEY_PATTERN,
              ContentFilter::GITHUB_TOKEN_PATTERN,
              ContentFilter::BEARER_TOKEN_PATTERN
            ].each { |pattern| result = result.gsub(pattern, marker) }
            config.custom_patterns.each { |pattern| result = result.gsub(pattern, marker) }
            result
          end
        end
      end
    end
  end
end
