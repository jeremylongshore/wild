# frozen_string_literal: true

require "yaml"

module Wild
  module CapabilityGate
    class Evaluator
      # Loads grant configuration from a YAML file.
      #
      # Expected format (from 002-AT-STND-capability-model.md):
      #
      #   grants:
      #     - caller: "service-account:introspection-agent"
      #       capabilities:
      #         - basic_introspection
      #         - privileged_introspection
      #
      #     - caller: "*"
      #       capabilities:
      #         - basic_introspection
      #
      class GrantLoader
        class GrantConfigError < StandardError; end

        def self.load_file(path)
          new(path).load
        end

        def initialize(path)
          @path = path
        end

        # Returns an array of Grant structs.
        def load
          raw = read_yaml
          validate_structure(raw)
          parse_grants(raw.fetch("grants"))
        end

        private

        def read_yaml
          content = File.read(@path)
          parsed = YAML.safe_load(content, permitted_classes: [Symbol])
          raise GrantConfigError, "#{@path}: file is empty or not valid YAML" if parsed.nil?

          parsed
        rescue Errno::ENOENT
          raise GrantConfigError, "#{@path}: file not found"
        rescue Psych::SyntaxError => e
          raise GrantConfigError, "#{@path}: YAML syntax error — #{e.message}"
        end

        def validate_structure(raw)
          raise GrantConfigError, "#{@path}: missing top-level 'grants' key" unless raw.is_a?(Hash)
          raise GrantConfigError, "#{@path}: missing top-level 'grants' key" unless raw.key?("grants")
          raise GrantConfigError, "#{@path}: 'grants' must be an array" unless raw["grants"].is_a?(Array)
        end

        def parse_grants(entries)
          entries.map.with_index do |entry, index|
            parse_grant(entry, index)
          end
        end

        def parse_grant(entry, index)
          validate_grant_entry(entry, index)
          validate_grant_capabilities(entry, index)

          Grant.new(
            caller_id: String(entry.fetch("caller")),
            capabilities: entry.fetch("capabilities").map(&:to_sym).freeze
          )
        end

        def validate_grant_entry(entry, index)
          raise GrantConfigError, "#{@path}: grant at index #{index} must be a hash" unless entry.is_a?(Hash)
          raise GrantConfigError, "#{@path}: grant at index #{index} missing 'caller'" unless entry.key?("caller")

          return if entry.key?("capabilities")

          raise GrantConfigError, "#{@path}: grant at index #{index} missing 'capabilities'"
        end

        def validate_grant_capabilities(entry, index)
          capabilities = entry.fetch("capabilities")
          return if capabilities.is_a?(Array) && capabilities.all? { |c| c.is_a?(String) || c.is_a?(Symbol) }

          raise GrantConfigError, "#{@path}: grant at index #{index} 'capabilities' must be an array of strings"
        end
      end
    end
  end
end
