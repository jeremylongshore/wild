# frozen_string_literal: true

module Wild::Hooks
  module TestSupport
    module HookFixtures
      # --- Hook Definition Fixtures ---

      def valid_definition_attrs(overrides = {})
        {
          name: 'before_tool_call',
          trigger: :before_tool_call,
          description: 'Fires before any tool call',
          required_permissions: ['tools.execute'],
          version: '1.0.0',
          deprecated: false
        }.merge(overrides)
      end

      def build_definition(overrides = {})
        Models::HookDefinition.new(**valid_definition_attrs(overrides))
      end

      def build_deprecated_definition(name: 'old_hook')
        build_definition(name: name, trigger: :on_error, deprecated: true)
      end

      # --- Hook Handler Fixtures ---

      def noop_callable
        ->(_ctx) { :noop }
      end

      def value_callable(value)
        ->(_ctx) { value }
      end

      def error_callable(msg = 'handler error')
        ->(_ctx) { raise StandardError, msg }
      end

      def slow_callable(sleep_ms: 200)
        lambda { |_ctx|
          sleep(sleep_ms / 1000.0)
          :slow_result
        }
      end

      def context_capturing_callable
        received = []
        callable = lambda { |ctx|
          received << ctx
          :captured
        }
        [callable, received]
      end

      def build_handler(overrides = {})
        Models::HookHandler.new(
          hook_name: 'before_tool_call',
          callable: noop_callable,
          **overrides
        )
      end

      # --- Registry Setup Helpers ---

      def setup_registry_with_hook(hook_name: 'before_tool_call', trigger: :before_tool_call)
        registry = Registry::HookRegistry.new
        registry.define(name: hook_name, trigger: trigger)
        registry
      end

      def setup_registry_with_handler(hook_name: 'before_tool_call', callable: nil,
                                      priority: 100, timeout_ms: nil)
        registry = setup_registry_with_hook(hook_name: hook_name)
        callable ||= noop_callable
        handler = registry.register_handler(
          hook_name: hook_name,
          callable: callable,
          priority: priority,
          timeout_ms: timeout_ms
        )
        [registry, handler]
      end

      # --- Result Helpers ---

      def build_result(overrides = {})
        handler = overrides.delete(:handler) || build_handler
        Models::HookResult.new(
          handler: handler,
          outcome: :success,
          duration_ms: 1.0,
          **overrides
        )
      end

      def build_event(overrides = {})
        Models::HookEvent.new(
          hook_name: 'before_tool_call',
          handler_id: 'handler_before_tool_call_123_456',
          outcome: :success,
          duration_ms: 1.5,
          **overrides
        )
      end
    end
  end
end
