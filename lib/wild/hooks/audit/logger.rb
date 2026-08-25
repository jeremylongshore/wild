# frozen_string_literal: true

module Wild
  module Hooks
    module Audit
      # Records HookEvent entries for each handler execution.
      #
      # Respects enable_audit_logging and max_audit_entries configuration.
      # When the audit log is full, the oldest entries are dropped (ring buffer).
      class Logger
        def initialize(config: Wild.config.hooks, trail: nil, sanitizer: nil)
          @config    = config
          @trail     = trail || Trail.new(max_entries: config.max_audit_entries)
          @sanitizer = sanitizer || Sanitizer.new
        end

        def record(hook_result, context = {})
          return unless @config.enable_audit_logging

          event = Models::HookEvent.new(
            hook_name: hook_result.handler&.hook_name.to_s,
            handler_id: hook_result.handler&.id.to_s,
            outcome: hook_result.outcome,
            duration_ms: hook_result.duration_ms,
            context_summary: summarise_context(context),
            error_message: hook_result.error&.message
          )

          @trail.append(event)
          event
        end

        attr_reader :trail

        private

        def summarise_context(context)
          return "" unless context.is_a?(Hash) && !context.empty?

          # F2 (wild-rvv, hooks audit): route every context value through the
          # Sanitizer before it lands in the trail. Without this, a raw
          # password/token/api_key passed as hook context was recorded
          # verbatim via v.inspect (f-l01-1).
          @sanitizer.sanitize(context).map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
        end
      end
    end
  end
end
