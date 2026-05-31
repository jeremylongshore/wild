# frozen_string_literal: true

require "yaml"

module Wild
  module Analyzers
    module Permission
      module Loaders
        class GrantsLoader
          def self.load(path)
            new(path).load
          end

          def initialize(path)
            @path = path
          end

          def load
            raw = parse_yaml
            entries = extract_entries(raw)
            entries.map { |entry| build_grant(entry) }.compact
          end

          private

          def parse_yaml
            content = File.read(@path)
            YAML.safe_load(content, permitted_classes: []) || {}
          rescue Errno::ENOENT
            raise Wild::Analyzers::Permission::LoadError, "Grants file not found: #{@path}"
          rescue Psych::Exception => e
            raise Wild::Analyzers::Permission::LoadError, "Invalid YAML in grants file: #{e.message}"
          end

          def extract_entries(raw)
            unless raw.is_a?(Hash) && raw["grants"].is_a?(Array)
              raise Wild::Analyzers::Permission::LoadError,
                    "grants.yml must have a top-level 'grants' array"
            end

            raw["grants"]
          end

          # rubocop:disable Metrics/AbcSize -- 3 guard clauses + 4-field build
          def build_grant(entry)
            return nil unless entry.is_a?(Hash)
            return nil unless entry["caller_id"].is_a?(String) && !entry["caller_id"].strip.empty?
            return nil unless entry["capabilities"].is_a?(Array)

            Models::Grant.new(
              caller_id: entry["caller_id"].strip,
              capabilities: entry["capabilities"].grep(String),
              context: entry["context"].is_a?(Hash) ? entry["context"] : {},
              expires_at: entry["expires_at"]
            )
          end
          # rubocop:enable Metrics/AbcSize
        end
      end
    end
  end
end
