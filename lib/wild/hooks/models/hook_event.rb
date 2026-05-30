# frozen_string_literal: true

module Wild::Hooks
  module Models
    # An immutable audit record of a single hook execution.
    class HookEvent
      CONTEXT_SUMMARY_MAX_LENGTH = 200

      attr_reader :id,
                  :hook_name,
                  :handler_id,
                  :outcome,
                  :duration_ms,
                  :timestamp,
                  :context_summary,
                  :error_message

      def initialize(hook_name:, handler_id:, outcome:, duration_ms:, context_summary: nil,
                     error_message: nil)
        @hook_name       = String(hook_name)
        @handler_id      = String(handler_id)
        @outcome         = outcome.to_sym
        @duration_ms     = Float(duration_ms)
        @timestamp       = Time.now
        @context_summary = truncate(String(context_summary.to_s))
        @error_message   = error_message&.to_s
        @id              = generate_id
      end

      def to_h
        {
          id: id,
          hook_name: hook_name,
          handler_id: handler_id,
          outcome: outcome,
          duration_ms: duration_ms,
          timestamp: timestamp,
          context_summary: context_summary,
          error_message: error_message
        }
      end

      def inspect
        "#<Wild::Hooks::Models::HookEvent id=#{id.inspect} hook_name=#{hook_name.inspect} " \
          "outcome=#{outcome.inspect} timestamp=#{timestamp}>"
      end

      private

      def generate_id
        "event_#{hook_name}_#{timestamp.to_i}_#{object_id}"
      end

      def truncate(str)
        return str if str.length <= CONTEXT_SUMMARY_MAX_LENGTH

        "#{str[0, CONTEXT_SUMMARY_MAX_LENGTH - 3]}..."
      end
    end
  end
end
