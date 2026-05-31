# frozen_string_literal: true

require "mcp"

module Wild
  module AdminTools
    module Server
      module Tools
        class ManageFeatureFlags < MCP::Tool
          tool_name "manage_feature_flags"
          # rubocop:disable Layout/LineLength
          description "Manage feature flags: read, list, toggle, enable/disable for actors, set percentage, or delete. " \
                      "Mutating actions require two-phase confirmation — call without nonce to preview, " \
                      "then call with the returned nonce to confirm."
          # rubocop:enable Layout/LineLength

          input_schema(
            properties: {
              action: {
                type: "string",
                enum: %w[read_flag list_flags toggle_flag enable_flag_for_actor
                         disable_flag_for_actor enable_flag_percentage delete_flag],
                description: "The feature flag action to perform"
              },
              nonce: { type: "string", description: "Confirmation nonce from a prior preview response" },
              flag_name: { type: "string", description: "The name of the feature flag" },
              enabled: { type: "boolean", description: "Whether the flag should be enabled or disabled" },
              actor_type: { type: "string", description: "The type of actor (e.g. User, Team)" },
              actor_id: { type: "string", description: "The ID of the actor" },
              percentage: { type: "integer", description: "Percentage of traffic to enable (0-100)" },
              filter: { type: "string", description: "Filter flags by name pattern" },
              enabled_only: { type: "boolean", description: "Only return enabled flags when listing" },
              limit: { type: "integer", description: "Maximum number of results to return" }
            },
            required: ["action"]
          )

          annotations(read_only_hint: false, destructive_hint: true)

          class << self
            def call(action:, server_context: nil, nonce: nil, **params)
              ToolHandler.execute(
                action_name: action,
                params: params.compact,
                server_context: server_context,
                nonce: nonce
              )
            end
          end
        end
      end
    end
  end
end
