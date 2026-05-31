# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class OutcomeDistribution < TelemetryRecord
          attr_reader :action, :distribution, :total_count

          def initialize(data)
            super
            @action = data["action"]
            # Support both 'distribution' and 'outcomes' keys per upstream contract
            @distribution = data["distribution"] || data["outcomes"] || {}
            @total_count = data["total_count"] || 0
          end

          def percentage_for(outcome)
            distribution[outcome.to_s] || 0.0
          end
        end
      end
    end
  end
end
