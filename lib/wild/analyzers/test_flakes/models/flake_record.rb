# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Models
        class FlakeRecord
          attr_reader :test_identity, :results, :root_causes, :first_seen, :last_seen

          def initialize(test_identity:, results:, root_causes: [], first_seen: nil, last_seen: nil)
            raise ArgumentError, "test_identity must be a TestIdentity" unless test_identity.is_a?(TestIdentity)
            raise ArgumentError, "results must be an Array" unless results.is_a?(Array)

            @test_identity = test_identity
            @results = results.freeze
            @root_causes = Array(root_causes).freeze
            @first_seen = first_seen || earliest_timestamp
            @last_seen = last_seen || latest_timestamp
          end

          def flake_rate
            return 0.0 if results.empty?

            failures = results.count(&:failed?)
            failures.to_f / results.size
          end

          def total_runs
            results.size
          end

          def failure_count
            results.count(&:failed?)
          end

          def pass_count
            results.count(&:passed?)
          end

          def run_ids
            results.map(&:run_id).uniq
          end

          def durations
            results.filter_map(&:duration_ms)
          end

          # rubocop:disable Metrics/AbcSize
          def duration_variance
            return 0.0 if durations.size < 2

            mean = durations.sum / durations.size.to_f
            variance = durations.sum { |d| (d - mean)**2 } / durations.size.to_f
            Math.sqrt(variance)
          end
          # rubocop:enable Metrics/AbcSize

          def primary_root_cause
            root_causes.max_by(&:confidence)
          end

          def to_h
            {
              test_identity: test_identity.to_h,
              flake_rate: flake_rate,
              total_runs: total_runs,
              failure_count: failure_count,
              first_seen: first_seen&.iso8601,
              last_seen: last_seen&.iso8601,
              root_causes: root_causes.map(&:to_h)
            }
          end

          private

          def earliest_timestamp
            results.map(&:timestamp).min
          end

          def latest_timestamp
            results.map(&:timestamp).max
          end
        end
      end
    end
  end
end
