# frozen_string_literal: true

module Wild
  module Hooks
    module McpServer
      # The shared outer wrapper for MCP tool execution: yield to the
      # namespace-specific block, rescue `StandardError`, hand the exception
      # to a caller-supplied formatter.
      #
      # Per-namespace identity / gate / audit / pipeline logic STAYS in the
      # respective namespace's `Server::ToolHandler` (in
      # `Wild::Introspection` and `Wild::AdminTools`). Only the
      # `rescue StandardError` pattern is shared. `Interrupt`, `SignalException`,
      # and other non-`StandardError` exceptions propagate unchanged, matching
      # the contract both old gems already had.
      module ToolHandler
        # Yields the actual tool invocation. On `StandardError`, calls the
        # caller-supplied `error_formatter` with the exception and returns
        # its value. If no formatter is supplied, the exception re-raises —
        # callers that want errors converted into MCP responses MUST pass
        # `error_formatter:`.
        #
        # @param error_formatter [#call, nil] takes one `StandardError`,
        #   returns whatever the consumer wants to surface (typically an
        #   `MCP::Tool::Response` constructed from the consumer's own
        #   response formatter)
        # @yieldreturn the value to return on success
        # @return [Object] the block's return value or the formatter's return
        #   value
        def self.wrap(error_formatter: nil)
          yield
        rescue StandardError => e
          raise unless error_formatter

          error_formatter.call(e)
        end
      end
    end
  end
end
