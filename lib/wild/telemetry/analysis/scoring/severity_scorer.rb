# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Scoring
        # Applies configurable per-type weight adjustments to raw gap severities.
        class SeverityScorer
          attr_reader :config

          def initialize(config: Wild.config.telemetry.analysis)
            @config = config
          end

          # Returns a new Gap with severity adjusted by the configured weight for its type.
          def score(gap)
            weight = config.severity_weights.fetch(gap.type, 1.0)
            adjusted = (gap.severity * weight).clamp(0.0, 1.0)

            Models::Gap.new(
              type: gap.type,
              action: gap.action,
              severity: adjusted,
              evidence: gap.evidence,
              description: gap.description,
              recommendation: gap.recommendation
            )
          end

          def score_all(gaps)
            gaps.map { |gap| score(gap) }
          end
        end
      end
    end
  end
end
