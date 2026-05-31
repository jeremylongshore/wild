# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class SessionSummary < TelemetryRecord
          attr_reader :caller_id, :event_count, :distinct_actions,
                      :outcome_breakdown, :total_duration_ms

          def initialize(data)
            super
            @caller_id = data["caller_id"]
            @event_count = data["event_count"] || 0
            @distinct_actions = Array(data["distinct_actions"])
            @outcome_breakdown = data["outcome_breakdown"] || {}
            @total_duration_ms = data["total_duration_ms"] || 0
          end

          def action_count
            distinct_actions.length
          end
        end
      end
    end
  end
end
