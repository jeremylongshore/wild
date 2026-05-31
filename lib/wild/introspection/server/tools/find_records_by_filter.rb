# frozen_string_literal: true

module Wild
  module Introspection
    module Server
      module Tools
        class FindRecordsByFilter < MCP::Tool
          tool_name "find_records_by_filter"
          description "Find records matching a field/value filter. " \
                      "Returns only columns permitted by the access policy."

          input_schema(
            properties: {
              model_name: {
                type: "string",
                description: 'The Rails model class name (e.g. "Account", "User")'
              },
              field: {
                type: "string",
                description: "The column name to filter on (must be in the access allowlist)"
              },
              value: {
                type: "string",
                description: "The value to match against the filter field"
              }
            },
            required: %w[model_name field value]
          )

          annotations(
            read_only_hint: true,
            destructive_hint: false,
            idempotent_hint: true
          )

          class << self
            def call(model_name:, field:, value:, server_context: nil)
              ToolHandler.execute(
                action: "find_records_by_filter",
                resource: model_name,
                server_context: server_context
              ) do |request_context|
                Guard::QueryGuard.find_by_filter(
                  model_name, field: field, value: value, request_context: request_context
                )
              end
            end
          end
        end
      end
    end
  end
end
