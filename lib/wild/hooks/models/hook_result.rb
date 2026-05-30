# frozen_string_literal: true

module Wild::Hooks
  module Models
    # The result of executing a single HookHandler.
    class HookResult
      VALID_OUTCOMES = %i[success error timeout skipped].freeze

      attr_reader :handler,
                  :outcome,
                  :duration_ms,
                  :error,
                  :return_value,
                  :executed_at

      def initialize(handler:, outcome:, duration_ms:, error: nil, return_value: nil)
        @handler      = handler
        @outcome      = validate_outcome!(outcome)
        @duration_ms  = Float(duration_ms)
        @error        = error
        @return_value = return_value
        @executed_at  = Time.now
      end

      def success?
        outcome == :success
      end

      def error?
        outcome == :error
      end

      def timeout?
        outcome == :timeout
      end

      def skipped?
        outcome == :skipped
      end

      def to_h
        {
          handler_id: handler&.id,
          hook_name: handler&.hook_name,
          outcome: outcome,
          duration_ms: duration_ms,
          error: error&.message,
          return_value: return_value,
          executed_at: executed_at
        }
      end

      def inspect
        "#<Wild::Hooks::Models::HookResult handler_id=#{handler&.id.inspect} " \
          "outcome=#{outcome.inspect} duration_ms=#{duration_ms}>"
      end

      private

      def validate_outcome!(outcome)
        raise ArgumentError, "outcome must be one of #{VALID_OUTCOMES.inspect}" \
          unless VALID_OUTCOMES.include?(outcome)

        outcome
      end
    end
  end
end
