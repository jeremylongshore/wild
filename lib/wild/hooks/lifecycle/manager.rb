# frozen_string_literal: true

module Wild::Hooks
  module Lifecycle
    # Manages hook and handler lifecycle operations.
    #
    # Provides enable/disable/deprecate operations and coordinates version
    # tracking for definition changes.
    class Manager
      def initialize(registry:, version_tracker: nil)
        @registry        = registry
        @version_tracker = version_tracker || VersionTracker.new
      end

      # Enable a specific handler by ID.
      def enable_handler(handler_id)
        handler = find_handler!(handler_id)
        handler.enable!
        handler
      end

      # Disable a specific handler by ID.
      def disable_handler(handler_id)
        handler = find_handler!(handler_id)
        handler.disable!
        handler
      end

      # Enable all handlers registered for a hook.
      def enable_all_for(hook_name)
        @registry.definition_for(hook_name)
        handlers = @registry.handler_store.for_hook(hook_name)
        handlers.each(&:enable!)
        handlers
      end

      # Disable all handlers registered for a hook.
      def disable_all_for(hook_name)
        @registry.definition_for(hook_name)
        handlers = @registry.handler_store.for_hook(hook_name)
        handlers.each(&:disable!)
        handlers
      end

      # Mark a hook definition as deprecated. Records the version change.
      def deprecate_hook(hook_name)
        definition = @registry.definition_for(hook_name)
        # We use instance_variable_set to mutate the immutable-by-convention field
        # since HookDefinition does not expose a setter intentionally.
        definition.instance_variable_set(:@deprecated, true)
        @version_tracker.record(hook_name, definition.version)
        definition
      end

      # Update the version of a hook definition and record in history.
      def update_version(hook_name, new_version)
        definition = @registry.definition_for(hook_name)
        definition.instance_variable_set(:@version, String(new_version))
        @version_tracker.record(hook_name, new_version)
        definition
      end

      def version_history_for(hook_name)
        @version_tracker.history_for(hook_name)
      end

      private

      def find_handler!(handler_id)
        handler = @registry.handler_store.find_by_id(handler_id)
        raise Error, "Handler not found: #{handler_id.inspect}" if handler.nil?

        handler
      end
    end
  end
end
