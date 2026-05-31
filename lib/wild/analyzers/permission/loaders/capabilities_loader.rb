# frozen_string_literal: true

require "yaml"

module Wild
  module Analyzers
    module Permission
      module Loaders
        class CapabilitiesLoader
          def self.load(path)
            new(path).load
          end

          def initialize(path)
            @path = path
          end

          def load
            raw = parse_yaml
            entries = extract_entries(raw)
            entries.map { |entry| build_capability(entry) }.compact
          end

          private

          def parse_yaml
            content = File.read(@path)
            YAML.safe_load(content, permitted_classes: []) || {}
          rescue Errno::ENOENT
            raise Wild::Analyzers::Permission::LoadError, "Capabilities file not found: #{@path}"
          rescue Psych::Exception => e
            raise Wild::Analyzers::Permission::LoadError, "Invalid YAML in capabilities file: #{e.message}"
          end

          def extract_entries(raw)
            unless raw.is_a?(Hash) && raw["capabilities"].is_a?(Array)
              raise Wild::Analyzers::Permission::LoadError,
                    "capabilities.yml must have a top-level 'capabilities' array"
            end

            raw["capabilities"]
          end

          def build_capability(entry)
            return nil unless valid_entry?(entry)

            Models::Capability.new(
              name: entry["name"].strip,
              description: entry["description"].to_s,
              risk_level: normalize_risk(entry["risk_level"]),
              prerequisites: Array(entry["prerequisites"]),
              tags: Array(entry["tags"])
            )
          end

          def valid_entry?(entry)
            entry.is_a?(Hash) && entry["name"].is_a?(String) && !entry["name"].strip.empty?
          end

          def normalize_risk(value)
            r = value.to_s.downcase
            r.empty? ? "low" : r
          end
        end
      end
    end
  end
end
