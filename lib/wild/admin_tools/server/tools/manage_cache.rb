# frozen_string_literal: true

require "mcp"

module Wild
  module AdminTools
    module Server
      module Tools
        class ManageCache < MCP::Tool
          tool_name "manage_cache"
          description "Manage application cache: inspect keys, view stats, list keys, or invalidate entries. " \
                      "Mutating actions require two-phase confirmation — call without nonce to preview, " \
                      "then call with the returned nonce to confirm."

          input_schema(
            properties: {
              action: {
                type: "string",
                enum: %w[inspect_cache_key inspect_cache_stats list_cache_keys
                         invalidate_cache_key invalidate_cache_pattern],
                description: "The cache action to perform"
              },
              nonce: { type: "string", description: "Confirmation nonce from a prior preview response" },
              cache_key: { type: "string", description: "A specific cache key to inspect or invalidate" },
              pattern: { type: "string", description: "Pattern for bulk cache invalidation" },
              prefix: { type: "string", description: "Prefix to filter cache keys when listing" },
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
