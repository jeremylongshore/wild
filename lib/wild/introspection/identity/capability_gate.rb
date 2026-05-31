# frozen_string_literal: true

module Wild
  module Introspection
    module Identity
      # CapabilityGate defines the interface that tool handlers use to check
      # whether a caller has the capability to perform a specific action on
      # a specific resource.
      #
      # In v1, this is a transparent stub: all authenticated callers are
      # permitted all actions. When wild-capability-gate ships, this module
      # becomes the integration point — replace the stub logic with a real
      # gate check without changing the call sites.
      #
      # Integration contract for Epic 10:
      #   CapabilityGate.permitted?(request_context, action:, resource:) → boolean
      #
      # See 009-AT-ADEC-capability-gate-interface.md for the full contract.
      module CapabilityGate
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
          # v1 stub: all authenticated callers have full capability.
          # When wild-capability-gate ships, this becomes:
          #   WildCapabilityGate.check(request_context.caller_id, action: action, resource: resource)
          request_context.authenticated?
        end

        # Returns the standard denial response for capability check failure.
        def self.denial_response
          CAPABILITY_DENIAL
        end
      end
    end
  end
end
