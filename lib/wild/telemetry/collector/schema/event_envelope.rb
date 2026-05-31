# frozen_string_literal: true

require "time"

module Wild
  module Telemetry
    module Collector
      module Schema
        class EventEnvelope
          attr_reader :event_type, :timestamp, :caller_id, :action, :outcome,
                      :duration_ms, :metadata, :received_at, :schema_version

          # rubocop:disable Metrics/ParameterLists
          def initialize(event_type:, timestamp:, caller_id:, action:, outcome:,
                         duration_ms: nil, metadata: nil, received_at: nil, schema_version: "1.0")
            @event_type = event_type
            @timestamp = timestamp
            @caller_id = caller_id
            @action = action
            @outcome = outcome
            @duration_ms = duration_ms
            @metadata = (metadata || {}).freeze
            @received_at = received_at || Time.now.utc.iso8601(3)
            @schema_version = schema_version
            freeze
          end
          # rubocop:enable Metrics/ParameterLists

          def to_h
            {
              event_type: @event_type,
              timestamp: @timestamp,
              caller_id: @caller_id,
              action: @action,
              outcome: @outcome,
              duration_ms: @duration_ms,
              metadata: @metadata.dup,
              received_at: @received_at,
              schema_version: @schema_version
            }
          end

          def self.from_raw(hash)
            h = hash.transform_keys(&:to_sym)
            new(
              event_type: h[:event_type],
              timestamp: h[:timestamp],
              caller_id: h[:caller_id],
              action: h[:action],
              outcome: h[:outcome],
              duration_ms: h[:duration_ms],
              metadata: h[:metadata]
            )
          end
        end
      end
    end
  end
end
