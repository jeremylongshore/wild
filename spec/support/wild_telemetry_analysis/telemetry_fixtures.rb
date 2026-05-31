# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module TestSupport
        module TelemetryFixtures
          HEADER_DATA = {
            "export_type" => "session_telemetry",
            "schema_version" => "1.0",
            "exported_at" => "2025-01-15T10:00:00Z",
            "source_id" => "test-source-001",
            "time_range" => { "start" => "2025-01-14T00:00:00Z", "end" => "2025-01-15T00:00:00Z" },
            "record_counts" => { "events" => 100, "summaries" => 5 }
          }.freeze

          def build_header(overrides = {})
            Wild::Telemetry::Analysis::Models::ExportHeader.new(HEADER_DATA.merge(overrides))
          end

          def build_event(overrides = {})
            data = {
              "record_type" => "event", "event_type" => "tool_call",
              "timestamp" => "2025-01-15T10:00:00Z", "caller_id" => "caller-001",
              "action" => "read_file", "outcome" => "success", "duration_ms" => 50, "metadata" => {}
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::EventRecord.new(data)
          end

          def build_session_summary(overrides = {})
            data = {
              "record_type" => "session_summary", "caller_id" => "caller-001",
              "event_count" => 10, "distinct_actions" => %w[read_file write_file list_dir],
              "outcome_breakdown" => { "success" => 8, "denied" => 2 }, "total_duration_ms" => 500
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::SessionSummary.new(data)
          end

          def build_tool_utilization(overrides = {})
            data = {
              "record_type" => "tool_utilization", "action" => "read_file",
              "invocation_count" => 20, "unique_callers" => 3,
              "success_rate" => 0.9, "avg_duration_ms" => 45.0
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::ToolUtilization.new(data)
          end

          def build_outcome_distribution(overrides = {})
            data = {
              "record_type" => "outcome_distribution", "action" => "read_file",
              "total_count" => 20, "outcomes" => { "success" => 0.8, "denied" => 0.1, "error" => 0.1 }
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::OutcomeDistribution.new(data)
          end

          def build_latency_stats(overrides = {})
            data = {
              "record_type" => "latency_stats", "action" => "read_file",
              "p50_ms" => 100.0, "p95_ms" => 300.0, "p99_ms" => 450.0,
              "min_ms" => 10.0, "max_ms" => 600.0, "avg_ms" => 120.0, "sample_count" => 50
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::LatencyStats.new(data)
          end

          def build_pattern_record(overrides = {})
            data = {
              "record_type" => "pattern", "pattern_type" => "retry_loop",
              "sequence" => %w[read_file read_file read_file],
              "occurrence_count" => 5, "unique_callers" => 2
            }.merge(overrides)
            Wild::Telemetry::Analysis::Models::PatternRecord.new(data)
          end

          def build_gap(overrides = {})
            defaults = {
              type: :denial, action: "read_file", severity: 0.5,
              evidence: { denial_rate: 0.5 }, description: "Test gap description",
              recommendation: "Test recommendation"
            }
            Wild::Telemetry::Analysis::Models::Gap.new(**defaults, **overrides)
          end

          def minimal_records
            {
              outcome_distribution: [build_outcome_distribution],
              tool_utilization: [build_tool_utilization],
              latency_stats: [build_latency_stats],
              session_summary: [build_session_summary],
              pattern: [build_pattern_record]
            }
          end

          def valid_jsonl
            [HEADER_DATA, valid_jsonl_event, valid_jsonl_utilization, valid_jsonl_distribution]
              .map { |l| JSON.generate(l) }.join("\n")
          end

          private

          def valid_jsonl_event
            { "record_type" => "event", "event_type" => "tool_call",
              "timestamp" => "2025-01-15T10:00:00Z", "caller_id" => "c1",
              "action" => "read_file", "outcome" => "success", "duration_ms" => 50 }
          end

          def valid_jsonl_utilization
            { "record_type" => "tool_utilization", "action" => "read_file",
              "invocation_count" => 10, "unique_callers" => 2,
              "success_rate" => 0.9, "avg_duration_ms" => 50.0 }
          end

          def valid_jsonl_distribution
            { "record_type" => "outcome_distribution", "action" => "read_file",
              "total_count" => 10, "outcomes" => { "success" => 0.9, "denied" => 0.1 } }
          end
        end
      end
    end
  end
end
