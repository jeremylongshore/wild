# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class ToolUtilization < TelemetryRecord
          attr_reader :action, :invocation_count, :unique_callers,
                      :success_rate, :avg_duration_ms

          def initialize(data)
            super
            @action = data["action"]
            @invocation_count = data["invocation_count"] || 0
            @unique_callers = data["unique_callers"] || 0
            @success_rate = data["success_rate"] || 0.0
            @avg_duration_ms = data["avg_duration_ms"] || 0.0
          end
        end
      end
    end
  end
end
