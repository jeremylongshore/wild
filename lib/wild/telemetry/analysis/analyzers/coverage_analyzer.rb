# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies callers that use a suspiciously narrow fraction of available actions.
        class CoverageAnalyzer < Base
          def analyze(records)
            session_summaries = Array(records[:session_summary])
            utilizations = Array(records[:tool_utilization])
            return [] if session_summaries.empty? || utilizations.empty?

            all_actions = utilizations.map(&:action).uniq
            return [] if all_actions.empty?

            gaps = session_summaries.filter_map { |s| coverage_gap_for(s, all_actions) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :coverage
          end

          private

          # rubocop:disable Metrics/AbcSize
          def coverage_gap_for(session, all_actions)
            covered = session.distinct_actions & all_actions
            fraction = covered.size.to_f / all_actions.size
            return nil if fraction >= config.coverage_min_fraction

            build_gap(
              action: session.caller_id,
              severity: clamp_severity(1.0 - fraction),
              evidence: coverage_evidence(covered, all_actions, fraction),
              description: coverage_description(session.caller_id, covered.size, all_actions.size, fraction),
              recommendation: "Review whether caller #{session.caller_id} is missing capabilities. " \
                              "Low coverage may indicate undiscovered tools."
            )
          end
          # rubocop:enable Metrics/AbcSize

          def coverage_evidence(covered, all_actions, fraction)
            {
              covered_actions: covered.size,
              total_actions: all_actions.size,
              coverage_fraction: fraction.round(4),
              coverage_min_fraction: config.coverage_min_fraction
            }
          end

          def coverage_description(caller_id, covered_count, total_count, fraction)
            "Caller #{caller_id} used #{covered_count}/#{total_count} actions " \
              "(#{(fraction * 100).round(1)}% coverage, " \
              "minimum: #{(config.coverage_min_fraction * 100).round(1)}%)"
          end
        end
      end
    end
  end
end
