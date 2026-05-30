# frozen_string_literal: true

require "mcp"

module Wild
  module Hooks
    module McpServer
      # Builds an `MCP::Server` with the given name, version, tools, and
      # server_context. This consolidates the `MCP::Server.new(...)` boilerplate
      # that lived independently at
      # `wild-rails-safe-introspection-mcp/.../server/server_factory.rb` and
      # `wild-admin-tools-mcp/.../server/server_factory.rb`.
      module Factory
        # @param name [String] server identifier, e.g. "wild-introspection"
        # @param version [String] semver string
        # @param tools [Array<Class>] subclasses of `MCP::Tool`
        # @param server_context [Hash] passed through to every tool invocation
        #   via the MCP protocol; per-namespace consumers shape its contents
        # @return [MCP::Server]
        def self.create(name:, version:, tools:, server_context: {})
          MCP::Server.new(
            name: name,
            version: version,
            tools: tools,
            server_context: server_context
          )
        end
      end
    end
  end
end
