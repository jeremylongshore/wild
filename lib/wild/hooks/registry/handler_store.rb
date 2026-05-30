# frozen_string_literal: true

module Wild::Hooks
  module Registry
    # Stores and queries HookHandler objects grouped by hook name.
    class HandlerStore
      def initialize(max_per_hook: 20)
        @handlers = Hash.new { |h, k| h[k] = [] }
        @max_per_hook = max_per_hook
        @mutex        = Mutex.new
      end

      def register(handler)
        raise ArgumentError, 'handler must be a HookHandler' \
          unless handler.is_a?(Models::HookHandler)

        @mutex.synchronize do
          current = @handlers[handler.hook_name]
          raise HandlerLimitExceededError.new(handler.hook_name, @max_per_hook) \
            if current.size >= @max_per_hook

          current << handler
        end

        handler
      end

      def for_hook(hook_name)
        @mutex.synchronize { @handlers[hook_name].dup }
      end

      def enabled_for_hook(hook_name)
        @mutex.synchronize { @handlers[hook_name].select(&:enabled?).dup }
      end

      def find_by_id(handler_id)
        @mutex.synchronize do
          @handlers.each_value do |handlers|
            found = handlers.find { |h| h.id == handler_id }
            return found if found
          end
          nil
        end
      end

      def all
        @mutex.synchronize { @handlers.values.flatten.dup }
      end

      def count_for(hook_name)
        @mutex.synchronize { @handlers[hook_name].size }
      end

      def total_count
        @mutex.synchronize { @handlers.values.sum(&:size) }
      end

      def hook_names
        @mutex.synchronize { @handlers.keys.dup }
      end

      def clear!
        @mutex.synchronize { @handlers.clear }
      end
    end
  end
end
