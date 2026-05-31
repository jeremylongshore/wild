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

      # Exact-symbol match BY DESIGN — CapabilityGate does NOT wildcard-match
      # capability names (F4 reconciliation, wild-lkp). A grant lists the
      # explicit capabilities it confers; capability-name wildcard expansion is
      # Wild::Analyzers::Permission's job (the auditing layer), not the gate's
      # (the runtime allow/deny). The only wildcard the gate honours is the
      # caller wildcard "*" (see #wildcard? / #matches_caller?), a different axis.
      def grants_capability?(capability_name)
        @capabilities.include?(capability_name.to_sym)
      end

      def matches_caller?(caller_id)
        wildcard? || @caller_id == String(caller_id)
      end
    end
  end
end
