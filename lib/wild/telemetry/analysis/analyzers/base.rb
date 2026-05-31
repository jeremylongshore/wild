# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        class Base
          attr_reader :config

          def initialize(config: Wild.config.telemetry.analysis)
            @config = config
          end

          # Subclasses implement this. records is a Hash<Symbol, Array<TelemetryRecord>>.
          # Returns Array<Models::Gap>.
          def analyze(_records)
            raise NotImplementedError, "#{self.class} must implement #analyze"
          end

          protected

          def gap_type
            raise NotImplementedError, "#{self.class} must implement #gap_type"
          end

          def build_gap(action:, severity:, evidence:, description:, recommendation: nil)
            Models::Gap.new(
              type: gap_type,
              action: action,
              severity: severity,
              evidence: evidence,
              description: description,
              recommendation: recommendation
            )
          end

          def clamp_severity(value)
            value.clamp(0.0, 1.0)
          end

          def limit_gaps(gaps)
            gaps.sort.first(config.max_gaps_per_type)
          end
        end
      end
    end
  end
end
