# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies tools/actions with high error/failure rates.
        class FailureAnalyzer < Base
          def analyze(records)
            utilizations = Array(records[:tool_utilization])
            return [] if utilizations.empty?

            gaps = utilizations.filter_map { |util| failure_gap_for(util) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :failure
          end

          private

          def failure_gap_for(util)
            failure_rate = 1.0 - util.success_rate.to_f
            return nil if failure_rate < config.failure_threshold

            build_gap(
              action: util.action,
              severity: clamp_severity(failure_rate),
              evidence: failure_evidence(util, failure_rate),
              description: failure_description(util.action, failure_rate, util.success_rate),
              recommendation: failure_recommendation(util.action, util.invocation_count, failure_rate)
            )
          end

          def failure_evidence(util, failure_rate)
            {
              failure_rate: failure_rate,
              success_rate: util.success_rate,
              threshold: config.failure_threshold,
              invocation_count: util.invocation_count
            }
          end

          def failure_description(action, failure_rate, success_rate)
            "#{action} has a failure rate of #{(failure_rate * 100).round(1)}% " \
              "(success rate: #{(success_rate * 100).round(1)}%)"
          end

          def failure_recommendation(action, invocation_count, failure_rate)
            "Investigate error patterns for #{action}. " \
              "#{invocation_count} invocations with #{(failure_rate * 100).round(1)}% failures."
          end
        end
      end
    end
  end
end
