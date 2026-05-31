# frozen_string_literal: true

module Wild
  module AdminTools
    module Server
      module ToolHandler
        def self.execute(action_name:, params:, server_context:, nonce: nil)
          pipeline = server_context&.fetch(:pipeline) { raise ConfigurationError, "No pipeline in server_context" }
          request_context = {
            caller_id: server_context[:caller_id],
            caller_type: server_context[:caller_type]
          }

          result = pipeline.call(action_name, params, request_context, nonce: nonce)
          ResponseFormatter.format(result)
        rescue StandardError => e
          ResponseFormatter.format_error(action_name, e)
        end
      end
    end
  end
end
