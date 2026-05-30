# frozen_string_literal: true

module Wild
  module Hooks
    module Health
      # Tracks per-handler execution health metrics.
      #
      # Identifies slow, failing, and stale handlers.
      class Monitor
        DEFAULT_SLOW_THRESHOLD_MS = 1_000.0
        DEFAULT_FAILURE_RATE_THRESHOLD = 0.5

        Metrics = Struct.new(
          :handler_id,
          :hook_name,
          :call_count,
          :success_count,
          :error_count,
          :timeout_count,
          :total_duration_ms
        ) do
          def avg_duration_ms
            return 0.0 if call_count.zero?

            total_duration_ms / call_count.to_f
          end

          def error_rate
            return 0.0 if call_count.zero?

            (error_count + timeout_count) / call_count.to_f
          end

          def success_rate
            return 0.0 if call_count.zero?

            success_count / call_count.to_f
          end

          def to_h
            {
              handler_id: handler_id,
              hook_name: hook_name,
              call_count: call_count,
              success_count: success_count,
              error_count: error_count,
              timeout_count: timeout_count,
              total_duration_ms: total_duration_ms,
              avg_duration_ms: avg_duration_ms,
              error_rate: error_rate,
              success_rate: success_rate
            }
          end
        end

        def initialize
          @metrics = {}
          @mutex   = Mutex.new
        end

        def record(hook_result)
          return unless hook_result.handler

          @mutex.synchronize { update_metrics(hook_result) }
        end

        def metrics_for(handler_id)
          @mutex.synchronize { @metrics[handler_id] }
        end

        def all_metrics
          @mutex.synchronize { @metrics.values.dup }
        end

        def slow_handlers(threshold_ms: DEFAULT_SLOW_THRESHOLD_MS)
          @mutex.synchronize do
            @metrics.values.select { |m| m.avg_duration_ms > threshold_ms }
          end
        end

        def failing_handlers(threshold: DEFAULT_FAILURE_RATE_THRESHOLD)
          @mutex.synchronize do
            @metrics.values.select { |m| m.call_count.positive? && m.error_rate > threshold }
          end
        end

        # Returns handler_ids that have been registered in the store but never called.
        def stale_handlers(all_registered_handler_ids)
          known_ids = @mutex.synchronize { @metrics.keys.to_set }
          all_registered_handler_ids.reject { |id| known_ids.include?(id) }
        end

        def clear!
          @mutex.synchronize { @metrics.clear }
        end

        private

        # rubocop:disable Metrics/AbcSize
        def update_metrics(hook_result)
          handler_id = hook_result.handler.id
          hook_name  = hook_result.handler.hook_name

          m = @metrics[handler_id] ||= Metrics.new(
            handler_id: handler_id,
            hook_name: hook_name,
            call_count: 0,
            success_count: 0,
            error_count: 0,
            timeout_count: 0,
            total_duration_ms: 0.0
          )

          m.call_count        += 1
          m.total_duration_ms += hook_result.duration_ms

          case hook_result.outcome
          when :success then m.success_count += 1
          when :error   then m.error_count += 1
          when :timeout then m.timeout_count += 1
          end
        end
        # rubocop:enable Metrics/AbcSize
      end
    end
  end
end
