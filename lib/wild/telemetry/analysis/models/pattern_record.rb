# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class PatternRecord < TelemetryRecord
          attr_reader :pattern_type, :sequence, :occurrence_count, :callers_affected

          def initialize(data)
            super
            @pattern_type = data["pattern_type"]
            @sequence = Array(data["sequence"])
            @occurrence_count = data["occurrence_count"] || 0
            # Support both 'unique_callers' (upstream contract) and 'callers_affected'
            @callers_affected = data["unique_callers"] || data["callers_affected"] || 0
          end

          def failure_cascade?
            pattern_type == "failure_cascade"
          end
        end
      end
    end
  end
end
