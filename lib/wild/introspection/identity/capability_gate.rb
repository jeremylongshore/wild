# frozen_string_literal: true

require "singleton"

module Wild
  module Introspection
    module Identity
      # CapabilityGate defines the interface that tool handlers use to check
      # whether a caller has the capability to perform a specific action on
      # a specific resource.
      #
      # This adapter routes authenticated callers through Wild::CapabilityGate.
      # A host must explicitly configure policy_path (a directory containing
      # capabilities.yml and grants.yml); an unset or invalid policy denies.
      #
      # Integration contract for Epic 10:
      #   CapabilityGate.permitted?(request_context, action:, resource:) → boolean
      #
      # See 009-AT-ADEC-capability-gate-interface.md for the full contract.
      module CapabilityGate
        REQUIRED_CAPABILITY = :basic_introspection
        CAPABILITY_DENIAL = {
          status: :denied,
          reason: :insufficient_capability,
          message: "The caller does not have the required capability."
        }.freeze

        ACTIONS = %w[
          inspect_model_schema
          lookup_record_by_id
          find_records_by_filter
        ].freeze

        # Check whether the caller has the capability to perform this action.
        #
        # @param request_context [Identity::RequestContext] the resolved caller identity
        # @param action [String] the tool action being invoked (e.g. 'inspect_model_schema')
        # @param resource [String, nil] the target resource (e.g. model name)
        # @return [Boolean] true if the caller is permitted
        def self.permitted?(request_context, action:, resource: nil) # rubocop:disable Lint/UnusedMethodArgument
          return false unless request_context.authenticated?

          gate.evaluate(caller: request_context.caller_id, capability: REQUIRED_CAPABILITY).allowed?
        rescue StandardError => e
          warn("[wild:introspection] capability gate denied evaluation: #{e.class}")
          false
        end

        def self.reset!
          @gate = nil
          @policy_path = nil
        end

        # Returns the standard denial response for capability check failure.
        def self.denial_response
          CAPABILITY_DENIAL
        end

        def self.gate
          policy_path = Wild.config.capability_gate.policy_path
          return DenyAllGate.instance if policy_path.nil?

          @gate = nil if @policy_path != policy_path
          @policy_path = policy_path
          @gate ||= Wild::CapabilityGate.new(config_path: policy_path)
        end
        private_class_method :gate

        class DenyAllGate
          include Singleton

          def evaluate(**)
            Wild::CapabilityGate::EvaluationResult.denied(
              capability_name: REQUIRED_CAPABILITY,
              caller_id: "unconfigured",
              reason: :policy_unavailable,
              details: "capability gate policy_path is not configured"
            )
          end
        end
      end
    end
  end
end
