# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies tools/actions with very low utilization — potential waste or dead code.
        class UtilizationAnalyzer < Base
          def analyze(records)
            utilizations = Array(records[:tool_utilization])
            return [] if utilizations.empty?

            gaps = utilizations.filter_map { |util| utilization_gap_for(util) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :utilization
          end

          private

          def utilization_gap_for(util)
            min_count = config.utilization_min_count
            return nil if util.invocation_count >= min_count

            ratio = util.invocation_count.to_f / min_count
            build_gap(
              action: util.action,
              severity: clamp_severity(1.0 - ratio),
              evidence: utilization_evidence(util, min_count),
              description: utilization_description(util.action, util.invocation_count, min_count),
              recommendation: utilization_recommendation(util.action)
            )
          end

          def utilization_evidence(util, min_count)
            {
              invocation_count: util.invocation_count,
              unique_callers: util.unique_callers,
              min_count_threshold: min_count
            }
          end

          def utilization_description(action, count, min_count)
            "#{action} was invoked only #{count} time(s), below the minimum utilization threshold of #{min_count}"
          end

          def utilization_recommendation(action)
            "Evaluate whether #{action} is discoverable and documented. " \
              "Low utilization may indicate redundancy or poor discoverability."
          end
        end
      end
    end
  end
end
