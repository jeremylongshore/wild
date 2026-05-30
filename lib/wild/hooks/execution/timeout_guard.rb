# frozen_string_literal: true

require "timeout"

module Wild
  module Hooks
    module Execution
      # Wraps a callable with a timeout constraint.
      #
      # Returns [:ok, return_value, duration_ms] or [:timeout, nil, duration_ms].
      class TimeoutGuard
        def initialize(timeout_ms)
          @timeout_ms = timeout_ms
        end

        def call(&)
          timeout_seconds = @timeout_ms / 1000.0
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return_value = Timeout.timeout(timeout_seconds, &)
          duration_ms = elapsed_ms(start)
          [:ok, return_value, duration_ms]
        rescue Timeout::Error
          duration_ms = elapsed_ms(start)
          [:timeout, nil, duration_ms]
        end

        private

        def elapsed_ms(start)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(3)
        end
      end
    end
  end
end
