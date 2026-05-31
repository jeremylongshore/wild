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
        rescue StandardError => e
          raise GateError.new("Gate evaluation failed: #{e.message}", original_error: e)
        end

        def configured?
          !@gate.nil?
        end
      end
    end
  end
end
