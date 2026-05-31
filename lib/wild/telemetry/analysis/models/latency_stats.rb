# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class LatencyStats < TelemetryRecord
          attr_reader :action, :p50, :p95, :p99, :min, :max, :avg, :sample_count

          def initialize(data)
            super
            @action = data["action"]
            @p50 = ms_field(data, "p50")
            @p95 = ms_field(data, "p95")
            @p99 = ms_field(data, "p99")
            @min = ms_field(data, "min")
            @max = ms_field(data, "max")
            @avg = ms_field(data, "avg")
            @sample_count = data["sample_count"] || 0
          end

          private

          # Accepts both `key_ms` (upstream contract) and bare `key` forms.
          def ms_field(data, key)
            data["#{key}_ms"] || data[key] || 0.0
          end
        end
      end
    end
  end
end
