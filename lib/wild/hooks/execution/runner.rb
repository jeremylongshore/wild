# frozen_string_literal: true

module Wild
  module Hooks
    module Execution
      # Executes all enabled handlers for a named hook in priority order.
      #
      # Each handler is wrapped with timeout enforcement and error isolation.
      # Returns an Array of HookResult objects.
      class Runner
        # Number of observability-sink failures (audit_logger/health_monitor
        # raising) isolated since this Runner was built. f-l01-2: a raising
        # sink must not abort the invocation after the handler already ran,
        # but it must not be silently swallowed either (council F2).
        attr_reader :observability_failures

        def initialize(registry:, config: Wild.config.hooks, audit_logger: nil,
                       health_monitor: nil)
          @registry       = registry
          @config         = config
          @audit_logger   = audit_logger
          @health_monitor = health_monitor
          @isolator       = ErrorIsolator.new
          @observability_failures = 0
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

            isolate_observability("audit_logger") { @audit_logger&.record(result, context) }
            isolate_observability("health_monitor") { @health_monitor&.record(result) }

            break if result.error? && @config.on_handler_error == :halt
          end

          results
        end

        private

        # Isolate an observability sink (audit_logger/health_monitor) so a
        # raising sink cannot abort the invocation after the handler already
        # ran. The failure is not swallowed: it increments
        # observability_failures and is logged via Wild.config.audit_logger
        # (same escape hatch used by CapabilityGate::Evaluator for its own
        # audit-emission failures), so an observability-pipeline outage is
        # itself observable rather than silent.
        def isolate_observability(sink_name)
          yield
        rescue StandardError => e
          @observability_failures += 1
          log_observability_failure(sink_name, e)
        end

        def log_observability_failure(sink_name, error)
          logger = Wild.config.audit_logger
          return unless logger.respond_to?(:error)

          logger.error(
            "[wild:hooks] #{sink_name} observability sink failed: " \
            "#{error.class}: #{error.message}"
          )
        rescue StandardError
          # The configured logger is itself broken. There is nowhere left to
          # write; do not raise out of the Runner. observability_failures was
          # already incremented above, so the failure remains countable even
          # when the log line itself cannot be emitted.
          nil
        end

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
end
