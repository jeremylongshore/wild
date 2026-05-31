# frozen_string_literal: true

module Wild
  module Introspection
    module Server
      module ServerFactory
        TOOLS = [
          Tools::InspectModelSchema,
          Tools::LookupRecordById,
          Tools::FindRecordsByFilter
        ].freeze

        def self.create(server_context: {})
          MCP::Server.new(
            name: "wild-rails-safe-introspection",
            version: Wild::VERSION,
            tools: TOOLS,
            server_context: server_context
          )
        end
      end
    end
  end
end
