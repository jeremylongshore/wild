# frozen_string_literal: true

module Wild::Hooks
  module Audit
    # Stores and queries HookEvent audit records.
    #
    # Operates as a capped ring buffer: when max_entries is reached, the oldest
    # entry is evicted to make room for the new one.
    class Trail
      def initialize(max_entries: 10_000)
        @max_entries = max_entries
        @events      = []
        @mutex       = Mutex.new
      end

      def append(event)
        raise ArgumentError, 'event must be a HookEvent' \
          unless event.is_a?(Models::HookEvent)

        @mutex.synchronize do
          @events.shift if @events.size >= @max_entries
          @events << event
        end

        event
      end

      def all
        @mutex.synchronize { @events.dup }
      end

      def count
        @mutex.synchronize { @events.size }
      end

      # Query by hook name.
      def for_hook(hook_name)
        @mutex.synchronize { @events.select { |e| e.hook_name == hook_name }.dup }
      end

      # Query by outcome symbol.
      def by_outcome(outcome)
        @mutex.synchronize { @events.select { |e| e.outcome == outcome }.dup }
      end

      # Query by handler_id.
      def for_handler(handler_id)
        @mutex.synchronize { @events.select { |e| e.handler_id == handler_id }.dup }
      end

      # Query by time range. Both bounds are optional.
      def in_range(from: nil, to: nil)
        @mutex.synchronize do
          @events.select do |e|
            (from.nil? || e.timestamp >= from) &&
              (to.nil? || e.timestamp <= to)
          end.dup
        end
      end

      def clear!
        @mutex.synchronize { @events.clear }
      end
    end
  end
end
