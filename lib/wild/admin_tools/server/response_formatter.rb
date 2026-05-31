# frozen_string_literal: true

require "json"

module Wild
  module AdminTools
    module Server
      module ResponseFormatter
        def self.format(result)
          body = result_to_hash(result)
          is_error = result.denied? || result.error?

          MCP::Tool::Response.new(
            [{ type: "text", text: JSON.generate(body) }],
            error: is_error,
            structured_content: body
          )
        end

        def self.format_error(action_name, error)
          body = {
            status: "error",
            action: action_name,
            message: error.message
          }

          MCP::Tool::Response.new(
            [{ type: "text", text: JSON.generate(body) }],
            error: true,
            structured_content: body
          )
        end

        def self.result_to_hash(result)
          case result.status
          when :success then success_hash(result)
          when :preview then preview_hash(result)
          when :denied  then denied_hash(result)
          when :error   then error_hash(result)
          end
        end

        private_class_method :result_to_hash

        def self.success_hash(result)
          {
            status: "success",
            action: result.action,
            operation: result.operation,
            data: result.data,
            before_snapshot: result.before_snapshot,
            after_snapshot: result.after_snapshot,
            metadata: result.metadata
          }.compact
        end

        def self.preview_hash(result)
          {
            status: "preview",
            action: result.action,
            operation: result.operation,
            data: result.data,
            metadata: result.metadata
          }.compact
        end

        def self.denied_hash(result)
          {
            status: "denied",
            action: result.action,
            **result.metadata
          }
        end

        def self.error_hash(result)
          {
            status: "error",
            action: result.action,
            message: result.metadata[:message] || "An error occurred"
          }
        end

        private_class_method :success_hash, :preview_hash, :denied_hash, :error_hash
      end
    end
  end
end
