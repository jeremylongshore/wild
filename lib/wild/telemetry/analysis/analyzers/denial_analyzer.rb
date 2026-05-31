# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies tools/actions with high denial rates.
        class DenialAnalyzer < Base
          def analyze(records)
            distributions = Array(records[:outcome_distribution])
            return [] if distributions.empty?

            gaps = distributions.filter_map { |dist| denial_gap_for(dist) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :denial
          end

          private

          def denial_gap_for(dist)
            denial_rate = dist.percentage_for("denied")
            return nil if denial_rate < config.denial_threshold

            build_gap(
              action: dist.action,
              severity: clamp_severity(denial_rate),
              evidence: denial_evidence(dist, denial_rate),
              description: denial_description(dist.action, denial_rate),
              recommendation: denial_recommendation(dist.action)
            )
          end

          def denial_evidence(dist, denial_rate)
            {
              denial_rate: denial_rate,
              threshold: config.denial_threshold,
              total_count: dist.total_count
            }
          end

          def denial_description(action, denial_rate)
            "#{action} has a denial rate of #{(denial_rate * 100).round(1)}% " \
              "(threshold: #{(config.denial_threshold * 100).round(1)}%)"
          end

          def denial_recommendation(action)
            "Review permission configuration for #{action}. " \
              "High denial rates indicate callers lack required capabilities."
          end
        end
      end
    end
  end
end
