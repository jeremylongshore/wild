# frozen_string_literal: true

require "mcp"

module Wild
  module AdminTools
    module Server
      module Tools
        class ManageBackgroundJobs < MCP::Tool
          tool_name "manage_background_jobs"
          description "Manage background jobs: inspect, list, retry, or discard. " \
                      "Mutating actions require two-phase confirmation — call without nonce to preview, " \
                      "then call with the returned nonce to confirm."

          input_schema(
            properties: {
              action: {
                type: "string",
                enum: %w[inspect_job list_failed_jobs list_queues retry_job discard_job
                         retry_jobs_by_filter discard_jobs_by_filter],
                description: "The background job action to perform"
              },
              nonce: { type: "string", description: "Confirmation nonce from a prior preview response" },
              job_id: { type: "string", description: "The ID of a specific job" },
              queue_name: { type: "string", description: "Filter by queue name" },
              error_class: { type: "string", description: "Filter by error class" },
              limit: { type: "integer", description: "Maximum number of results to return" },
              max_count: { type: "integer", description: "Maximum number of jobs to affect in bulk operations" },
              filter: { type: "object", description: "Filter criteria for bulk operations" }
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
