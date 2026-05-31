# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Triage
        class SeverityScorer
          def initialize(weights: nil)
            config = Wild.config.analyzers.test_flakes
            @weights = weights || config.severity_weights
          end

          def score(flake_record, trend: :stable)
            components = weighted_components(flake_record, trend)
            raw = components.sum / total_weight
            [raw, 1.0].min.round(4)
          end

          def severity_from_score(score)
            case score
            when 0.75..Float::INFINITY then :critical
            when 0.5...0.75 then :high
            when 0.25...0.5 then :medium
            else :low
            end
          end

          TREND_MULTIPLIERS = { worsening: 0.9, stable: 0.5, improving: 0.1 }.freeze

          private

          def weighted_components(flake_record, trend)
            [
              flake_record.flake_rate * @weights[:flake_rate],
              failure_count_score(flake_record.failure_count) * @weights[:failure_count],
              trend_multiplier(trend) * @weights[:trend],
              top_confidence(flake_record) * @weights[:confidence]
            ]
          end

          def failure_count_score(count)
            [Math.log10([count, 1].max) / 3.0, 1.0].min
          end

          def trend_multiplier(trend)
            TREND_MULTIPLIERS.fetch(trend, 0.5)
          end

          def top_confidence(flake_record)
            return 0.0 if flake_record.root_causes.empty?

            flake_record.root_causes.map(&:confidence).max || 0.0
          end

          def total_weight
            @weights.values.sum.to_f
          end
        end
      end
    end
  end
end
