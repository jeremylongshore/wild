# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Detection
        class FlakeDetector
          def initialize(minimum_runs: nil, flake_rate_threshold: nil)
            config = Wild.config.analyzers.test_flakes
            @minimum_runs = minimum_runs || config.minimum_runs
            @flake_rate_threshold = flake_rate_threshold || config.flake_rate_threshold
            @comparator = Comparator.new
          end

          def detect(results)
            raise DetectionError, "results must be an Array" unless results.is_a?(Array)

            grouped = @comparator.group_by_identity(results)
            grouped.filter_map do |_key, group_results|
              build_flake_record(group_results)
            end
          end

          private

          def build_flake_record(group_results)
            return nil if group_results.size < @minimum_runs
            return nil unless @comparator.both_outcomes?(group_results)

            rate = @comparator.flake_rate(group_results)
            return nil if rate < @flake_rate_threshold

            identity = group_results.first.test_identity
            Models::FlakeRecord.new(
              test_identity: identity,
              results: group_results
            )
          end
        end
      end
    end
  end
end
