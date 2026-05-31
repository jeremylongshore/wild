# frozen_string_literal: true

module Wild
  module AdminTools
    module Identity
      SessionContext = Data.define(
        :caller_id,
        :caller_type,
        :authenticated,
        :gate_result,
        :capabilities
      ) do
        def initialize(
          caller_id:,
          caller_type: "unknown",
          authenticated: false,
          gate_result: "not_checked",
          capabilities: []
        )
          super
        end

        def anonymous?
          caller_id.nil? || caller_id.to_s.strip.empty?
        end

        def authenticated?
          authenticated == true
        end

        def gate_allowed?
          gate_result == "allowed"
        end

        def gate_denied?
          gate_result == "denied"
        end

        def with_gate_result(result, updated_capabilities: capabilities)
          self.class.new(
            caller_id: caller_id,
            caller_type: caller_type,
            authenticated: authenticated,
            gate_result: result,
            capabilities: updated_capabilities
          )
        end
      end
    end
  end
end
