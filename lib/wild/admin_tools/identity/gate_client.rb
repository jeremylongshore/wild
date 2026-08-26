# frozen_string_literal: true

module Wild
  module AdminTools
    module Identity
      class GateClient
        def initialize(gate:)
          @gate = gate
        end

        def authorize(session_context, action_name, params: {})
          raise GateError, "Gate is not configured" if @gate.nil?

          capability = :"admin_tools.#{action_name}"
          result = @gate.evaluate(
            caller: session_context.caller_id,
            capability: capability,
            context: { action_params: params }
          )

          gate_result = result.allowed? ? "allowed" : "denied"
          session_context.with_gate_result(gate_result, updated_capabilities: result.allowed? ? [capability] : [])
        rescue GateError
          raise
        rescue *Wild::CapabilityGate::DEVELOPER_ERRORS => e
          # f-l08-3: a CapabilityGate developer-bug signal (audit-schema
          # misconfiguration) must not be wrapped into an ordinary GateError —
          # AuthenticatedPipeline#authorize_via_gate only rescues GateError, so
          # wrapping it here would let it get silently demoted to a generic
          # "gate_denied" with the real cause discarded. Log the class + a safe
          # message before re-raising so the failure is observable even though
          # the exception itself is about to propagate.
          log_developer_error(e)
          raise
        rescue StandardError => e
          raise GateError.new("Gate evaluation failed: #{e.message}", original_error: e)
        end

        def configured?
          !@gate.nil?
        end

        private

        # @api private
        # rubocop:disable Style/StderrPuts -- deliberate: `warn` is a Kernel#warn
        # no-op under $VERBOSE = nil, matching the capability_gate fix this
        # mirrors (f-l08 addendum item 1).
        def log_developer_error(error)
          message = "[wild:admin_tools] capability gate raised a developer error: #{error.class}: #{error.message}"
          logger = Wild.config.audit_logger
          logger.respond_to?(:error) ? logger.error(message) : $stderr.puts(message)
        rescue StandardError
          nil
        end
        # rubocop:enable Style/StderrPuts
      end
    end
  end
end
