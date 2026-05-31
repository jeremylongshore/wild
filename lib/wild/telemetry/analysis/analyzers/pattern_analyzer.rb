# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies recurring patterns (e.g., failure cascades) that indicate systemic gaps.
        class PatternAnalyzer < Base
          def analyze(records)
            pattern_records = Array(records[:pattern])
            return [] if pattern_records.empty?

            gaps = pattern_records.filter_map { |p| pattern_gap_for(p) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :pattern
          end

          private

          def pattern_gap_for(pattern)
            return nil if pattern.occurrence_count < config.pattern_min_occurrences

            action_label = pattern.sequence.join(" -> ")
            build_gap(
              action: action_label,
              severity: compute_severity(pattern),
              evidence: pattern_evidence(pattern),
              description: pattern_description(pattern, action_label),
              recommendation: recommendation_for(pattern)
            )
          end

          def pattern_evidence(pattern)
            {
              pattern_type: pattern.pattern_type,
              sequence: pattern.sequence,
              occurrence_count: pattern.occurrence_count,
              callers_affected: pattern.callers_affected,
              min_occurrences: config.pattern_min_occurrences
            }
          end

          def pattern_description(pattern, action_label)
            "Pattern '#{pattern.pattern_type}' detected: #{action_label} " \
              "(#{pattern.occurrence_count} occurrences, #{pattern.callers_affected} callers)"
          end

          def compute_severity(pattern)
            # Failure cascades are considered higher severity
            base = pattern.failure_cascade? ? 0.6 : 0.3
            # Scale up with occurrence count (saturates at ~50 occurrences)
            occurrence_factor = [pattern.occurrence_count / 50.0, 0.4].min
            clamp_severity(base + occurrence_factor)
          end

          def recommendation_for(pattern)
            if pattern.failure_cascade?
              "Break the failure cascade in sequence: #{pattern.sequence.join(" -> ")}. " \
                "Add retry logic or circuit breakers."
            else
              "Investigate the recurring pattern: #{pattern.sequence.join(" -> ")}. " \
                "Appeared #{pattern.occurrence_count} times across #{pattern.callers_affected} callers."
            end
          end
        end
      end
    end
  end
end
