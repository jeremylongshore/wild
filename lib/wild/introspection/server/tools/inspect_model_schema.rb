# frozen_string_literal: true

module Wild
  module Introspection
    module Server
      module Tools
        class InspectModelSchema < MCP::Tool
          tool_name "inspect_model_schema"
          description "Inspect the schema (columns, types, associations) of a Rails model. " \
                      "Returns only columns permitted by the access policy."

          input_schema(
            properties: {
              model_name: {
                type: "string",
                description: 'The Rails model class name (e.g. "Account", "User")'
              }
            },
            required: ["model_name"]
          )

          annotations(
            read_only_hint: true,
            destructive_hint: false,
            idempotent_hint: true
          )

          class << self
            def call(model_name:, server_context: nil)
              ToolHandler.execute(
                action: "inspect_model_schema",
                resource: model_name,
                server_context: server_context
              ) do |request_context|
                Guard::QueryGuard.inspect_schema(model_name, request_context: request_context)
              end
            end
          end
        end
      end
    end
  end
end
