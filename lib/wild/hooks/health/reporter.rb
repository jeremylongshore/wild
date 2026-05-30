# frozen_string_literal: true

module Wild
  module Hooks
    module Health
      # Generates health reports from Monitor metrics.
      class Reporter
        def initialize(monitor:, registry: nil)
          @monitor  = monitor
          @registry = registry
        end

        # Returns a summary hash of overall hook system health.
        def summary
          all = @monitor.all_metrics

          {
            total_handlers_tracked: all.size,
            total_calls: all.sum(&:call_count),
            total_errors: all.sum(&:error_count),
            total_timeouts: all.sum(&:timeout_count),
            total_successes: all.sum(&:success_count),
            slow_handlers: @monitor.slow_handlers.map(&:handler_id),
            failing_handlers: @monitor.failing_handlers.map(&:handler_id),
            stale_handlers: stale_handler_ids
          }
        end

        # Returns a detailed per-handler report.
        def detailed
          @monitor.all_metrics.map(&:to_h)
        end

        # Returns a report for a specific handler.
        def for_handler(handler_id)
          metrics = @monitor.metrics_for(handler_id)
          return nil unless metrics

          metrics.to_h
        end

        private

        def stale_handler_ids
          return [] unless @registry

          all_ids = @registry.all_handlers.map(&:id)
          @monitor.stale_handlers(all_ids)
        end
      end
    end
  end
end
