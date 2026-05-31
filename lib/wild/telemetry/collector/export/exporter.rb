# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Telemetry
    module Collector
      module Export
        class Exporter
          def initialize(store:, record_builder: nil, aggregator: nil, pattern_detector: nil)
            @store = store
            @record_builder = record_builder || RecordBuilder.new
            @aggregator = aggregator
            @pattern_detector = pattern_detector
          end

          # rubocop:disable Metrics/AbcSize
          def export(since: nil, before: nil, event_type: nil, caller_id: nil)
            events = fetch_events(since: since, before: before, event_type: event_type)
            events = events.select { |e| e.caller_id == caller_id } if caller_id

            event_records = events.map { |e| @record_builder.event_record(e) }
            extra_records = aggregation_records(events) + pattern_records(events)
            header = build_header(since: since, before: before, event_count: event_records.size,
                                  extra_records: extra_records)

            lines = [JSON.generate(header)]
            (event_records + extra_records).each { |r| lines << JSON.generate(r) }
            lines
          end
          # rubocop:enable Metrics/AbcSize

          private

          def fetch_events(since:, before:, event_type:)
            @store.query(event_type: event_type, since: since, before: before)
          end

          def aggregation_records(events)
            return [] unless @aggregator

            rb = @record_builder
            [
              *@aggregator.session_summaries(events).map { |s| rb.session_summary_record(s) },
              *@aggregator.tool_utilization(events).map { |u| rb.tool_utilization_record(u) },
              *@aggregator.outcome_distributions(events).map { |d| rb.outcome_distribution_record(d) },
              *@aggregator.latency_stats(events).map { |l| rb.latency_stats_record(l) }
            ]
          end

          def pattern_records(events)
            return [] unless @pattern_detector

            rb = @record_builder
            [
              *@pattern_detector.detect_sequences(events).map { |p| rb.pattern_record(p) },
              *@pattern_detector.detect_failure_cascades(events).map { |p| rb.pattern_record(p) }
            ]
          end

          def build_header(since:, before:, event_count:, extra_records: [])
            counts = { events: event_count }
            extra_records.each do |r|
              type = r[:record_type]
              counts[type] = (counts[type] || 0) + 1
            end
            @record_builder.header(
              schema_version: "1.0.0",
              exported_at: Time.now.utc.iso8601(3),
              time_range: { start: since, end: before },
              record_counts: counts
            )
          end
        end
      end
    end
  end
end
