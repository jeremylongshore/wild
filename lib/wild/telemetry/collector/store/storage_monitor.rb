# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Store
        class StorageMonitor
          def initialize(store:)
            @store = store
          end

          def stats
            {
              event_count: @store.count,
              size_bytes: size_bytes,
              oldest_event: oldest_event_timestamp,
              newest_event: newest_event_timestamp,
              store_type: @store.class.name
            }
          end

          def healthy?
            @store.count >= 0
          rescue StandardError
            false
          end

          private

          def size_bytes
            return @store.size_bytes if @store.respond_to?(:size_bytes)

            nil
          end

          def oldest_event_timestamp
            events = @store.recent(limit: @store.count)
            return nil if events.empty?

            events.last.received_at
          rescue StandardError
            nil
          end

          def newest_event_timestamp
            events = @store.recent(limit: 1)
            return nil if events.empty?

            events.first.received_at
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
