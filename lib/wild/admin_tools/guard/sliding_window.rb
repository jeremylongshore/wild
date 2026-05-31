# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      # Thread-safe sliding window counter for rate limiting.
      # Timestamps are stored as Float (Process.clock_gettime) for sub-second precision.
      class SlidingWindow
        def initialize(max_count, window_seconds)
          @max_count = max_count
          @window_seconds = window_seconds
          @timestamps = []
          @mutex = Mutex.new
        end

        def allow?
          @mutex.synchronize do
            prune!
            return false if @timestamps.size >= @max_count

            @timestamps << Process.clock_gettime(Process::CLOCK_MONOTONIC)
            true
          end
        end

        def remaining
          @mutex.synchronize do
            prune!
            @max_count - @timestamps.size
          end
        end

        def retry_after_seconds
          @mutex.synchronize do
            prune!
            return 0 if @timestamps.size < @max_count

            oldest = @timestamps.first
            expiry = oldest + @window_seconds
            [expiry - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max.ceil
          end
        end

        def reset!
          @mutex.synchronize { @timestamps.clear }
        end

        private

        def prune!
          cutoff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @window_seconds
          @timestamps.reject! { |ts| ts < cutoff }
        end
      end
    end
  end
end
