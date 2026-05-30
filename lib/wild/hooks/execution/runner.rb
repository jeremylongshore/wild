# frozen_string_literal: true

module Wild::Hooks
  module Execution
    # Executes all enabled handlers for a named hook in priority order.
    #
    # Each handler is wrapped with timeout enforcement and error isolation.
    # Returns an Array of HookResult objects.
    class Runner
      def initialize(registry:, config: Wild.config.hooks, audit_logger: nil,
                     health_monitor: nil)
        @registry       = registry
        @config         = config
        @audit_logger   = audit_logger
        @health_monitor = health_monitor
        @isolator       = ErrorIsolator.new
      end

      # Execute all enabled handlers registered for hook_name.
      #
      # @param hook_name [String] the name of the hook to execute
      # @param context [Hash] contextual data passed to each handler
      # @return [Array<Models::HookResult>] results in execution order
      def execute(hook_name, context = {})
        raise HookNotFoundError, hook_name unless @registry.hook_defined?(hook_name)

        handlers = @registry.handlers_for(hook_name)
        results  = []

        handlers.each do |handler|
          result = execute_handler(handler, context)
          results << result

          @audit_logger&.record(result, context)
          @health_monitor&.record(result)

          break if result.error? && @config.on_handler_error == :halt
        end

        results
      end

      private

      def execute_handler(handler, context)
        timeout_ms = handler.timeout_ms || @config.default_timeout_ms
        guard      = TimeoutGuard.new(timeout_ms)

        outcome, return_value, duration_ms = guard.call do
          status, value = @isolator.call { handler.call(context) }
          [status, value]
        end

        if outcome == :timeout
          build_result(handler, :timeout, duration_ms, nil, nil)
        else
          status, value = return_value
          if status == :error
            build_result(handler, :error, duration_ms, value, nil)
          else
            build_result(handler, :success, duration_ms, nil, value)
          end
        end
      end

      def build_result(handler, outcome, duration_ms, error, return_value)
        Models::HookResult.new(
          handler: handler,
          outcome: outcome,
          duration_ms: duration_ms,
          error: error,
          return_value: return_value
        )
      end
    end
  end
end
