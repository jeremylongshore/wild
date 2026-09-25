# frozen_string_literal: true

require "yaml"

module Wild
  module CapabilityGate
    class Registry
      # Loads capability definitions from a YAML configuration file.
      #
      # Expected format (from 002-AT-STND-capability-model.md):
      #
      #   capabilities:
      #     - name: basic_introspection
      #       description: "Read-only schema inspection"
      #       risk_level: standard
      #       prerequisites: []
      #
      #     - name: privileged_introspection
      #       description: "Full runtime introspection"
      #       risk_level: elevated
      #       prerequisites:
      #         - type: file_exists
      #           path: "config/safety-attestation-introspection.md"
      #
      class ConfigLoader
        class ConfigError < StandardError; end

        def self.load_file(path)
          new(path).load
        end

        def initialize(path)
          @path = path
        end

        def load
          raw = read_yaml
          validate_structure(raw)
          parse_capabilities(raw.fetch("capabilities"))
        end

        private

        def read_yaml
          content = File.read(@path)
          parsed = YAML.safe_load(content, permitted_classes: [Symbol])
          raise ConfigError, "#{@path}: file is empty or not valid YAML" if parsed.nil?

          parsed
        rescue Errno::ENOENT
          raise ConfigError, "#{@path}: file not found"
        rescue Psych::SyntaxError => e
          raise ConfigError, "#{@path}: YAML syntax error — #{e.message}"
        end

        def validate_structure(raw)
          raise ConfigError, "#{@path}: missing top-level 'capabilities' key" unless raw.is_a?(Hash)
          raise ConfigError, "#{@path}: missing top-level 'capabilities' key" unless raw.key?("capabilities")
          raise ConfigError, "#{@path}: 'capabilities' must be an array" unless raw["capabilities"].is_a?(Array)
        end

        def parse_capabilities(entries)
          entries.map.with_index do |entry, index|
            parse_capability(entry, index)
          end
        end

        def parse_capability(entry, index)
          validate_capability_entry(entry, index)

          Capability.new(
            name: entry.fetch("name"),
            description: entry.fetch("description", ""),
            risk_level: entry.fetch("risk_level"),
            prerequisites: parse_prerequisites(entry.fetch("prerequisites", []))
          )
        rescue ArgumentError => e
          raise ConfigError, "#{@path}: capability at index #{index} — #{e.message}"
        end

        def validate_capability_entry(entry, index)
          raise ConfigError, "#{@path}: capability at index #{index} must be a hash" unless entry.is_a?(Hash)
          raise ConfigError, "#{@path}: capability at index #{index} missing 'name'" unless entry.key?("name")

          return if entry.key?("risk_level")

          raise ConfigError, "#{@path}: capability at index #{index} missing 'risk_level'"
        end

        def parse_prerequisites(entries)
          return [] unless entries.is_a?(Array)

          entries.map.with_index do |prereq, index|
            parse_prerequisite(prereq, index)
          end
        end

        def parse_prerequisite(entry, index)
          raise ConfigError, "prerequisite at index #{index} must be a hash" unless entry.is_a?(Hash)
          raise ConfigError, "prerequisite at index #{index} missing 'type'" unless entry.key?("type")

          type = entry.delete("type")
          params = entry.transform_keys(&:to_sym)
          validate_config_value_params(type, params, index)
          Prerequisite.new(type: type, **params)
        end

        # f-l08-1: a config_value prerequisite authored without `value:` has
        # `expected == nil` in ConfigValueChecker; if the same key is also
        # absent from the runtime context, that used to grant the
        # prerequisite unconditionally (`nil == nil`). Reject this shape at
        # load time so a policy-author typo (forgetting `value:`) can never
        # silently downgrade a gate to "always satisfied" — fail fast at
        # startup rather than fail open at evaluation time.
        def validate_config_value_params(type, params, index)
          return unless type.to_s == "config_value"
          return if params.key?(:value)

          raise ConfigError, "prerequisite at index #{index} (config_value) missing required 'value' parameter"
        end
      end
    end
  end
end
