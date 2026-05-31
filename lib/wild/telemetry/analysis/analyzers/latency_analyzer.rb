# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Analyzers
        # Identifies tools/actions with high p95 latency.
        class LatencyAnalyzer < Base
          def analyze(records)
            latency_records = Array(records[:latency_stats])
            return [] if latency_records.empty?

            gaps = latency_records.filter_map { |stat| latency_gap_for(stat) }
            limit_gaps(gaps)
          end

          protected

          def gap_type
            :latency
          end

          private

          def latency_gap_for(stat)
            p95 = stat.p95.to_f
            threshold = config.latency_p95_threshold_ms
            return nil if p95 <= threshold

            build_gap(
              action: stat.action,
              severity: latency_severity(p95, threshold),
              evidence: latency_evidence(stat, p95, threshold),
              description: "#{stat.action} p95 latency #{p95.round(1)}ms exceeds threshold of #{threshold.round(1)}ms",
              recommendation: "Profile #{stat.action} for performance bottlenecks. " \
                              "P95: #{p95.round(1)}ms, P99: #{stat.p99.round(1)}ms."
            )
          end

          def latency_severity(p95, threshold)
            # Severity scales with how much the threshold is exceeded (caps at 2x = 1.0)
            ratio = [p95 / threshold, 2.0].min
            clamp_severity(ratio - 1.0)
          end

          def latency_evidence(stat, p95, threshold)
            {
              p95_ms: p95,
              p99_ms: stat.p99,
              avg_ms: stat.avg,
              threshold_ms: threshold
            }
          end
        end
      end
    end
  end
end
