# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Telemetry
    module Collector
      module Export
        class RecordBuilder
          def header(schema_version:, exported_at:, time_range:, record_counts:)
            {
              export_type: "session_telemetry",
              schema_version: schema_version,
              exported_at: exported_at,
              time_range: time_range,
              record_counts: record_counts
            }
          end

          def event_record(envelope)
            h = envelope.respond_to?(:to_h) ? envelope.to_h : envelope
            fields = h.slice(:event_type, :timestamp, :caller_id, :action, :outcome, :duration_ms, :metadata)
            { record_type: "event" }.merge(fields)
          end

          def session_summary_record(hash)
            { record_type: "session_summary" }.merge(hash)
          end

          def tool_utilization_record(hash)
            { record_type: "tool_utilization" }.merge(hash)
          end

          def outcome_distribution_record(hash)
            { record_type: "outcome_distribution" }.merge(hash)
          end

          def latency_stats_record(hash)
            { record_type: "latency_stats" }.merge(hash)
          end

          def pattern_record(hash)
            { record_type: "pattern" }.merge(hash)
          end
        end
      end
    end
  end
end
