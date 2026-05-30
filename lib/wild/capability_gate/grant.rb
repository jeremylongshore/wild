# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Immutable value object representing a grant rule.
    #
    # Maps a caller identity to a set of capabilities they are granted.
    # A wildcard caller ("*") grants to all authenticated callers.
    class Grant
      WILDCARD = "*"

      attr_reader :caller_id, :capabilities

      def initialize(caller_id:, capabilities:)
        @caller_id = String(caller_id).freeze
        @capabilities = Array(capabilities).map(&:to_sym).freeze
        freeze
      end

      def wildcard?
        @caller_id == WILDCARD
      end

      def grants_capability?(capability_name)
        @capabilities.include?(capability_name.to_sym)
      end

      def matches_caller?(caller_id)
        wildcard? || @caller_id == String(caller_id)
      end
    end
  end
end
