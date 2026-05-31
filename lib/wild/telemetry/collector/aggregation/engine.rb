# frozen_string_literal: true

require "time"

module Wild
  module Telemetry
    module Collector
      module Aggregation
        class Engine
          DEFAULT_MIN_POPULATION = 5

          def initialize(min_population: DEFAULT_MIN_POPULATION)
            @min_population = min_population
          end

          def session_summaries(events, window_seconds: 3600)
            grouped = group_by_caller_and_window(events, window_seconds)
            grouped.filter_map do |(caller_id, window_start), bucket|
              next if bucket.size < @min_population

              build_summary(caller_id, window_start, window_seconds, bucket)
            end
          end

          # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
          def tool_utilization(events)
            events.group_by(&:action).filter_map do |action, bucket|
              next if bucket.size < @min_population

              success_count = bucket.count { |e| e.outcome == "success" }
              durations = bucket.filter_map(&:duration_ms)

              {
                action: action,
                invocation_count: bucket.size,
                unique_callers: bucket.map(&:caller_id).uniq.size,
                success_rate: success_count.fdiv(bucket.size),
                avg_duration_ms: durations.empty? ? nil : durations.sum.fdiv(durations.size)
              }
            end
          end
          # rubocop:enable Metrics/AbcSize,Metrics/CyclomaticComplexity

          def outcome_distributions(events)
            events.group_by(&:action).filter_map do |action, bucket|
              next if bucket.size < @min_population

              total = bucket.size
              outcomes = bucket.group_by(&:outcome).transform_values do |group|
                { count: group.size, percentage: group.size.fdiv(total).round(3) }
              end

              { action: action, total_count: total, outcomes: outcomes }
            end
          end

          def latency_stats(events)
            events
              .reject { |e| e.duration_ms.nil? }
              .group_by(&:action)
              .filter_map do |action, bucket|
                next if bucket.size < @min_population

                build_latency_record(action, bucket)
              end
          end

          private

          def group_by_caller_and_window(events, window_seconds)
            events.group_by do |e|
              ts = Time.parse(e.timestamp).to_i
              [e.caller_id, (ts / window_seconds) * window_seconds]
            end
          end

          def build_summary(caller_id, window_start, window_seconds, bucket)
            {
              caller_id: caller_id,
              window_start: Time.at(window_start).utc.iso8601,
              window_end: Time.at(window_start + window_seconds).utc.iso8601,
              event_count: bucket.size,
              distinct_actions: bucket.map(&:action).uniq.sort,
              outcome_breakdown: bucket.group_by(&:outcome).transform_values(&:size),
              total_duration_ms: bucket.filter_map(&:duration_ms).sum
            }
          end

          def build_latency_record(action, bucket)
            sorted = bucket.map(&:duration_ms).sort
            {
              action: action, sample_count: sorted.size,
              p50: percentile(sorted, 50), p95: percentile(sorted, 95), p99: percentile(sorted, 99),
              min: sorted.first, max: sorted.last, avg: sorted.sum.fdiv(sorted.size)
            }
          end

          def percentile(sorted, pct)
            return sorted.first if sorted.size == 1

            rank = (pct / 100.0 * (sorted.size - 1)).round
            sorted[rank]
          end
        end
      end
    end
  end
end
