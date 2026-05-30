# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Immutable value object representing a prerequisite definition.
    #
    # Describes what must be satisfied before a capability is granted.
    # The actual checking logic lives in the prerequisite checker (Epic 4).
    # See 002-AT-STND-capability-model.md for prerequisite types.
    class Prerequisite
      VALID_TYPES = %i[file_exists config_value].freeze

      attr_reader :type, :params

      def initialize(type:, **params)
        @type = validate_type(type)
        @params = params.freeze
        freeze
      end

      private

      def validate_type(type)
        sym = type.to_sym
        return sym if VALID_TYPES.include?(sym)

        raise ArgumentError,
              "unknown prerequisite type #{type.inspect}, must be one of: #{VALID_TYPES.join(", ")}"
      end
    end
  end
end
