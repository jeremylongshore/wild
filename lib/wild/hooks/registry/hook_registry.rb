# frozen_string_literal: true

module Wild::Hooks
  module Registry
    # Central registry combining DefinitionStore and HandlerStore.
    #
    # Provides the unified API for registering hook definitions and handlers,
    # and retrieving them for execution.
    class HookRegistry
      attr_reader :definition_store, :handler_store

      def initialize(config: Wild.config.hooks)
        @config           = config
        @definition_store = DefinitionStore.new
        @handler_store    = HandlerStore.new(max_per_hook: config.max_handlers_per_hook)
      end

      # Register a HookDefinition. Raises DuplicateHookError if already registered.
      def define(name:, trigger:, description: '', required_permissions: [], version: '1.0.0',
                 deprecated: false)
        definition = Models::HookDefinition.new(
          name: name,
          trigger: trigger,
          description: description,
          required_permissions: required_permissions,
          version: version,
          deprecated: deprecated
        )
        definition_store.register(definition)
      end

      # Register a handler callable for a named hook. The hook definition must exist.
      def register_handler(hook_name:, callable:, priority: 100, timeout_ms: nil, enabled: true,
                           metadata: {})
        raise HookNotFoundError, hook_name unless definition_store.registered?(hook_name)

        handler = Models::HookHandler.new(
          hook_name: hook_name,
          callable: callable,
          priority: priority,
          timeout_ms: timeout_ms,
          enabled: enabled,
          metadata: metadata
        )
        handler_store.register(handler)
      end

      # Returns enabled handlers for a hook, sorted by priority (ascending).
      def handlers_for(hook_name)
        handler_store.enabled_for_hook(hook_name).sort_by(&:priority)
      end

      # Returns the definition for the named hook. Raises HookNotFoundError if missing.
      def definition_for(hook_name)
        definition_store.fetch(hook_name)
      end

      def hook_defined?(hook_name)
        definition_store.registered?(hook_name)
      end

      def all_definitions
        definition_store.all
      end

      def all_handlers
        handler_store.all
      end

      def clear!
        definition_store.clear!
        handler_store.clear!
      end
    end
  end
end
