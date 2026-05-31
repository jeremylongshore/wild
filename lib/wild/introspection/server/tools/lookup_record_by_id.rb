# frozen_string_literal: true

module Wild
  module Introspection
    module Server
      module Tools
        class LookupRecordById < MCP::Tool
          tool_name "lookup_record_by_id"
          description "Look up a single record by its primary key. " \
                      "Returns only columns permitted by the access policy."

          input_schema(
            properties: {
              model_name: {
                type: "string",
                description: 'The Rails model class name (e.g. "Account", "User")'
              },
              id: {
                type: "string",
                description: "The record primary key value"
              }
            },
            required: %w[model_name id]
          )

          annotations(
            read_only_hint: true,
            destructive_hint: false,
            idempotent_hint: true
          )

          class << self
            def call(model_name:, id:, server_context: nil)
              ToolHandler.execute(
                action: "lookup_record_by_id",
                resource: model_name,
                server_context: server_context
              ) do |request_context|
                Guard::QueryGuard.find_by_id(model_name, id, request_context: request_context)
              end
            end
          end
        end
      end
    end
  end
end
