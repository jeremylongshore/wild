# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Ingestion
        class RecordFactory
          RECORD_TYPE_MAP = {
            "event" => Models::EventRecord,
            "session_summary" => Models::SessionSummary,
            "tool_utilization" => Models::ToolUtilization,
            "outcome_distribution" => Models::OutcomeDistribution,
            "latency_stats" => Models::LatencyStats,
            "pattern" => Models::PatternRecord
          }.freeze

          def self.build(data)
            record_type = data["record_type"]
            klass = RECORD_TYPE_MAP[record_type]

            if klass
              klass.new(data)
            else
              Models::TelemetryRecord.new(data)
            end
          end
        end
      end
    end
  end
end
