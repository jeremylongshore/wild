# frozen_string_literal: true

module Wild
  module Hooks
    module Models
      # A registered handler for a named hook point.
      #
      # Handlers are callables (Proc/lambda or any object responding to #call)
      # associated with a hook definition. Priority determines execution order
      # (lower numbers run first).
      class HookHandler
        attr_reader :id,
                    :hook_name,
                    :callable,
                    :priority,
                    :timeout_ms,
                    :metadata,
                    :registered_at

        attr_accessor :enabled

        alias enabled? enabled

        # rubocop:disable Metrics/ParameterLists -- domain model with 6 documented attrs
        def initialize(hook_name:, callable:, priority: 100, timeout_ms: nil, enabled: true,
                       metadata: {})
          # rubocop:enable Metrics/ParameterLists
          @hook_name     = validate_hook_name!(hook_name)
          @callable      = validate_callable!(callable)
          @priority      = validate_priority!(priority)
          @timeout_ms    = validate_timeout!(timeout_ms)
          @enabled       = enabled == true
          @metadata      = Hash(metadata).freeze
          @registered_at = Time.now.utc
          @id            = generate_id
        end

        def call(context = {})
          callable.call(context)
        end

        def enable!
          @enabled = true
          self
        end

        def disable!
          @enabled = false
          self
        end

        def to_h
          {
            id: id,
            hook_name: hook_name,
            priority: priority,
            timeout_ms: timeout_ms,
            enabled: enabled,
            metadata: metadata,
            registered_at: registered_at
          }
        end

        def inspect
          "#<Wild::Hooks::Models::HookHandler id=#{id.inspect} hook_name=#{hook_name.inspect} " \
            "priority=#{priority} enabled=#{enabled}>"
        end

        private

        def validate_hook_name!(name)
          raise ArgumentError, "hook_name must be a non-empty String" \
            unless name.is_a?(String) && !name.strip.empty?

          name
        end

        def validate_callable!(callable)
          raise InvalidHandlerError unless callable.respond_to?(:call)

          callable
        end

        def validate_priority!(priority)
          raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)

          priority
        end

        def validate_timeout!(timeout_ms)
          return nil if timeout_ms.nil?
          raise ArgumentError, "timeout_ms must be a positive Integer" \
            unless timeout_ms.is_a?(Integer) && timeout_ms.positive?

          timeout_ms
        end

        def generate_id
          "handler_#{hook_name}_#{object_id}_#{registered_at.to_i}"
        end
      end
    end
  end
end
