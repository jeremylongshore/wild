# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      class TwoPhaseFlow
        def initialize(nonce_manager: NonceManager.new)
          @nonce_manager = nonce_manager
        end

        attr_reader :nonce_manager

        def preview_with_nonce(action_name, params, caller_id, executor, action_config)
          preview_result = executor.preview(action_name, params)
          ttl = action_config["nonce_ttl_seconds"] || 30
          nonce = @nonce_manager.generate(action_name, params, caller_id, ttl_seconds: ttl)

          Result.new(
            status: :preview, action: action_name, operation: action_config["operation"],
            data: preview_result.data,
            metadata: preview_result.metadata.merge(nonce: nonce, requires_confirmation: true)
          )
        end

        def confirm_and_execute(nonce, action_name, params, caller_id, executor)
          validation = @nonce_manager.validate_and_consume!(nonce, action_name, params, caller_id)
          return nonce_denied_result(action_name, validation) unless validation[:valid]

          executor.execute(action_name, params)
        end

        private

        def nonce_denied_result(action_name, validation)
          Result.new(
            status: :denied, action: action_name, operation: "unknown",
            data: {},
            metadata: {
              reason: validation[:client_reason],
              internal_reason: validation[:internal_reason]
            }
          )
        end
      end
    end
  end
end
