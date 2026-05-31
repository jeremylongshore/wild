# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Store
        class MemoryStore < Base
          def initialize
            super
            @envelopes = []
            @mutex = Mutex.new
          end

          def append(envelope)
            @mutex.synchronize { @envelopes << envelope }
            envelope
          end

          def recent(limit: 50)
            @mutex.synchronize { @envelopes.last(limit).reverse }
          end

          def find(timestamp:, event_type:)
            @mutex.synchronize do
              @envelopes.find { |e| e.timestamp == timestamp && e.event_type == event_type }
            end
          end

          def count
            @mutex.synchronize { @envelopes.size }
          end

          def query(event_type: nil, since: nil, before: nil)
            @mutex.synchronize do
              results = @envelopes.dup
              results = results.select { |e| e.event_type == event_type } if event_type
              results = results.select { |e| e.timestamp >= since } if since
              results = results.select { |e| e.timestamp < before } if before
              results
            end
          end

          def clear!
            @mutex.synchronize { @envelopes.clear }
          end
        end
      end
    end
  end
end
