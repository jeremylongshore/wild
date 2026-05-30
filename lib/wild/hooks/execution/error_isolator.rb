# frozen_string_literal: true

module Wild::Hooks
  module Execution
    # Wraps a callable to catch and isolate errors.
    #
    # Returns [:ok, return_value] or [:error, exception].
    # Does NOT rescue Timeout::Error or SignalException — those propagate.
    class ErrorIsolator
      def call
        return_value = yield
        [:ok, return_value]
      rescue Timeout::Error, SignalException
        raise
      rescue StandardError => e
        [:error, e]
      end
    end
  end
end
