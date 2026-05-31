# frozen_string_literal: true

module Wild
  module Introspection
    module Server
      module ToolHandler
        def self.execute(action:, resource:, server_context:)
          request_context = resolve_identity(server_context)
          gate_denial = check_gate(request_context, action, resource)
          return gate_denial if gate_denial

          guard_result = yield(request_context)
          format_response(guard_result)
        rescue StandardError => e
          format_response(status: :error, reason: :internal_error, message: e.message)
        end

        def self.resolve_identity(server_context)
          api_key = server_context.is_a?(Hash) ? server_context[:api_key] : nil
          Identity::IdentityResolver.resolve(api_key: api_key)
        end
        private_class_method :resolve_identity

        def self.check_gate(request_context, action, resource)
          return nil if Identity::CapabilityGate.permitted?(request_context, action: action, resource: resource)

          denial = Identity::CapabilityGate.denial_response
          audit_gate_denial(action, resource, request_context, denial)
          format_response(denial)
        end
        private_class_method :check_gate

        def self.format_response(result)
          error = %i[denied error].include?(result[:status])
          content = [{ type: "text", text: JSON.generate(result) }]

          MCP::Tool::Response.new(content, error: error)
        end
        private_class_method :format_response

        def self.audit_gate_denial(action, resource, request_context, denial)
          Audit::Recorder.record(
            tool_name: action,
            model_name: resource.to_s,
            parameters: {},
            request_context: request_context
          ) { denial }
        end
        private_class_method :audit_gate_denial
      end
    end
  end
end
