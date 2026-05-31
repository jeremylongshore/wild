# frozen_string_literal: true

module Wild
  module AdminTools
    module Identity
      class AuthenticatedPipeline
        def initialize(audited_pipeline:, gate_client:, extractor: IdentityExtractor.new)
          @audited_pipeline = audited_pipeline
          @gate_client = gate_client
          @extractor = extractor
        end

        def call(action_name, params, request_context, nonce: nil)
          session = @extractor.extract(request_context)

          return deny_with_audit(action_name, params, session, "anonymous_request_rejected") if session.anonymous?

          session = authorize_via_gate(session, action_name, params)

          return deny_with_audit(action_name, params, session, "gate_denied") unless session.gate_allowed?

          @audited_pipeline.call(
            action_name, params, session.caller_id,
            nonce: nonce, session_context: session
          )
        end

        delegate :register_executor, to: :@audited_pipeline

        private

        def authorize_via_gate(session, action_name, params)
          @gate_client.authorize(session, action_name, params: params)
        rescue GateError
          session.with_gate_result("denied")
        end

        def deny_with_audit(action_name, params, session, reason)
          @audited_pipeline.recorder.record(
            action_name: action_name,
            params: params,
            caller_id: session.caller_id || "anonymous",
            session_context: session
          ) do
            Result.new(
              status: :denied,
              action: action_name,
              operation: "unknown",
              metadata: { reason: reason }
            )
          end
        end
      end
    end
  end
end
