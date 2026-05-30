# frozen_string_literal: true

module Wild
  module Hooks
    # Tier 1 substrate for MCP server transport per ADR-0003.
    #
    # Wild::Introspection and Wild::AdminTools both expose MCP servers. The
    # boilerplate of constructing `MCP::Server` (Factory) and wrapping tool
    # execution in a StandardError rescue (ToolHandler) lives here so the
    # two Tier 4 namespaces don't duplicate it.
    #
    # What is NOT in this substrate:
    #   - Identity resolution / capability-gate checks (per-namespace logic
    #     in Wild::Introspection::Server::ToolHandler)
    #   - Mutation pipelines / dry-run / confirmation protocol
    #     (per-namespace logic in Wild::AdminTools::Server::ToolHandler)
    #   - Response formatters (each namespace supplies its own via
    #     ToolHandler.wrap's `error_formatter:` parameter)
    #
    # Closes the structural-duplication portion of wild-rvv.6.1.
    # The `mcp` gem is required transitively from the Factory.
    module McpServer
    end
  end
end

require "wild/hooks/mcp_server/factory"
require "wild/hooks/mcp_server/tool_handler"
