# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Immutable value object representing a capability definition.
    #
    # Loaded from YAML config at startup. Not modifiable at runtime.
    # See 002-AT-STND-capability-model.md for the governing specification.
    class Capability
      VALID_RISK_LEVELS = %i[standard elevated critical].freeze

      attr_reader :name, :description, :risk_level, :prerequisites

      def initialize(name:, description:, risk_level:, prerequisites: [])
        @name = validate_name(name)
        @description = String(description)
        @risk_level = validate_risk_level(risk_level)
        @prerequisites = Array(prerequisites).freeze
        freeze
      end

      def standard?
        risk_level == :standard
      end

      def elevated?
        risk_level == :elevated
      end

      def critical?
        risk_level == :critical
      end

      def prerequisites?
        !prerequisites.empty?
      end

      private

      def validate_name(name)
        sym = name.to_sym
        raise ArgumentError, "capability name must not be empty" if sym.empty?

        sym
      end

      def validate_risk_level(level)
        sym = level.to_sym
        return sym if VALID_RISK_LEVELS.include?(sym)

        raise ArgumentError,
              "unknown risk_level #{level.inspect}, must be one of: #{VALID_RISK_LEVELS.join(", ")}"
      end
    end
  end
end
