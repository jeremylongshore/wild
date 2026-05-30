# frozen_string_literal: true

module Wild::Hooks
  module Registry
    # Stores and queries HookDefinition objects.
    class DefinitionStore
      def initialize
        @definitions = {}
        @mutex       = Mutex.new
      end

      def register(definition)
        raise ArgumentError, 'definition must be a HookDefinition' \
          unless definition.is_a?(Models::HookDefinition)
        raise DuplicateHookError, definition.name if @mutex.synchronize { @definitions.key?(definition.name) }

        @mutex.synchronize { @definitions[definition.name] = definition }
        definition
      end

      def fetch(name)
        @mutex.synchronize { @definitions[name] } ||
          raise(HookNotFoundError, name)
      end

      def find(name)
        @mutex.synchronize { @definitions[name] }
      end

      def registered?(name)
        @mutex.synchronize { @definitions.key?(name) }
      end

      def all
        @mutex.synchronize { @definitions.values.dup }
      end

      def deprecated
        @mutex.synchronize { @definitions.values.select(&:deprecated?) }
      end

      def active
        @mutex.synchronize { @definitions.values.reject(&:deprecated?) }
      end

      def by_trigger(trigger)
        @mutex.synchronize { @definitions.values.select { |d| d.trigger == trigger } }
      end

      def count
        @mutex.synchronize { @definitions.size }
      end

      def clear!
        @mutex.synchronize { @definitions.clear }
      end
    end
  end
end
