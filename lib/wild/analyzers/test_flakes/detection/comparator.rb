# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Detection
        class Comparator
          def self.group_by_identity(results)
            new.group_by_identity(results)
          end

          def group_by_identity(results)
            raise DetectionError, "results must be an Array" unless results.is_a?(Array)

            results.each_with_object({}) do |result, groups|
              next unless result.is_a?(Models::TestResult)

              key = result.test_identity.key
              groups[key] ||= []
              groups[key] << result
            end
          end

          def both_outcomes?(results)
            statuses = results.map(&:status).uniq
            passed = statuses.include?(:passed)
            failed = statuses.intersect?(%i[failed errored])
            passed && failed
          end

          def flake_rate(results)
            return 0.0 if results.empty?

            failed = results.count(&:failed?)
            failed.to_f / results.size
          end

          def run_ids_with_failures(results)
            results.select(&:failed?).map(&:run_id).uniq
          end

          def run_ids_with_passes(results)
            results.select(&:passed?).map(&:run_id).uniq
          end
        end
      end
    end
  end
end
