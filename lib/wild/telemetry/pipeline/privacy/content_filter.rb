# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Privacy
        class ContentFilter
          EMAIL_PATTERN = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
          IP_PATTERN = /\b(?:\d{1,3}\.){3}\d{1,3}\b/
          # Key-anchored: `prefix` captures the key name plus whatever
          # quoting/separator surrounds it (bare `api_key=`, JSON-quoted
          # `"api_key":"`, or hash-rocket `'api_key' => '`), `suffix`
          # captures an optional closing quote. Redactor#redact_pattern uses
          # both named groups to redact only the secret value, so a
          # JSON/Ruby-hash shape stays parseable after redaction (f-l03-2).
          API_KEY_PATTERN =
            /\b(?<prefix>(?:api[_-]?key|apikey|api_secret)['"]?\s*[:=]>?\s*['"]?)[A-Za-z0-9_-]{16,}(?<suffix>['"]?)/i
          AWS_ACCESS_KEY_PATTERN = /\b(?:AKIA|ASIA|AROA)[A-Z0-9]{16}\b/
          AWS_SECRET_KEY_PATTERN =
            %r{\b(?<prefix>(?:aws[_-]secret|secret_access_key)['"]?\s*[:=]>?\s*['"]?)[A-Za-z0-9+/]{40}(?<suffix>['"]?)}i
          GITHUB_TOKEN_PATTERN = /\bghp_[A-Za-z0-9]{36}\b|\bghs_[A-Za-z0-9]{36}\b/
          BEARER_TOKEN_PATTERN = %r{\bBearer\s+[A-Za-z0-9._\-+/=]{20,}}i
          ABSOLUTE_PATH_PATTERN = %r{\b(?:/(?:[^/\s]+/)*[^/\s]+)\b}
          FILE_CONTENT_PATTERN = /```[a-z]*\n[\s\S]+?\n```/m

          BUILT_IN_PATTERNS = [
            EMAIL_PATTERN,
            IP_PATTERN,
            API_KEY_PATTERN,
            AWS_ACCESS_KEY_PATTERN,
            AWS_SECRET_KEY_PATTERN,
            GITHUB_TOKEN_PATTERN,
            BEARER_TOKEN_PATTERN
          ].freeze

          def sensitive?(content, config: Wild.config.telemetry.pipeline)
            return false if content.to_s.strip.empty?

            all_patterns(config).any? { |pattern| pattern.match?(content) } ||
              (config.strip_absolute_paths && ABSOLUTE_PATH_PATTERN.match?(content)) ||
              (config.strip_file_contents && FILE_CONTENT_PATTERN.match?(content))
          end

          def patterns_matching(content, config: Wild.config.telemetry.pipeline)
            matched = []
            all_patterns(config).each { |p| matched << p if p.match?(content) }
            matched << ABSOLUTE_PATH_PATTERN if config.strip_absolute_paths && ABSOLUTE_PATH_PATTERN.match?(content)
            matched << FILE_CONTENT_PATTERN if config.strip_file_contents && FILE_CONTENT_PATTERN.match?(content)
            matched
          end

          private

          def all_patterns(config)
            BUILT_IN_PATTERNS + config.custom_patterns
          end
        end
      end
    end
  end
end
