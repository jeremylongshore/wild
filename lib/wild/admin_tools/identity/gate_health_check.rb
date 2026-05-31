# frozen_string_literal: true

module Wild
  module AdminTools
    module Identity
      class GateHealthCheck
        def initialize(gate_client:)
          @gate_client = gate_client
        end

        def check
          return unhealthy("Gate client is not configured") unless @gate_client.configured?

          # Probe with a harmless capability check
          probe_context = SessionContext.new(
            caller_id: "__health_check__",
            caller_type: "system",
            authenticated: true
          )
          @gate_client.authorize(probe_context, "__health_probe__")

          healthy
        rescue GateError => e
          unhealthy("Gate error: #{e.message}")
        rescue StandardError => e
          unhealthy("Unexpected error: #{e.message}")
        end

        private

        def healthy
          { status: "healthy", gate_configured: true }
        end

        def unhealthy(reason)
          { status: "unhealthy", gate_configured: @gate_client.configured?, reason: reason }
        end
      end
    end
  end
end
