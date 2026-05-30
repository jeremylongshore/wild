# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Immutable result of a capability evaluation.
    #
    # Every evaluation produces one of these — allowed or denied.
    # Denied results always carry a reason symbol and human-readable details.
    # See 002-AT-STND-capability-model.md for the result specification.
    class EvaluationResult
      DENIAL_REASONS = %i[
        unknown_capability
        not_granted
        prerequisite_not_met
        evaluation_error
      ].freeze

      attr_reader :capability_name, :caller_id, :reason, :details,
                  :prerequisites_checked, :timestamp

      def self.allowed(capability_name:, caller_id:, prerequisites_checked: [], timestamp: Time.now.utc)
        new(true, capability_name, caller_id,
            prerequisites_checked: prerequisites_checked, timestamp: timestamp)
      end

      def self.denied(capability_name:, caller_id:, reason:, details: nil, timestamp: Time.now.utc)
        new(false, capability_name, caller_id,
            reason: reason, details: details, timestamp: timestamp)
      end

      def allowed?
        @allowed
      end

      def denied?
        !@allowed
      end

      private

      # rubocop:disable Metrics/ParameterLists -- private factory; public API is .allowed/.denied
      def initialize(allowed, capability_name, caller_id, reason: nil, details: nil,
                     prerequisites_checked: [], timestamp: Time.now.utc)
        # rubocop:enable Metrics/ParameterLists
        @allowed = allowed
        @capability_name = capability_name.to_sym
        @caller_id = String(caller_id)
        @reason = reason
        @details = details
        @prerequisites_checked = Array(prerequisites_checked).freeze
        @timestamp = timestamp
        freeze
      end
    end
  end
end
