# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Analysis
        # rubocop:disable Metrics/ClassLength
        class RootCauseAnalyzer
          include SignalExtractors

          CONFIDENCE_THRESHOLD = 0.15

          def analyze(flake_records, all_results: [])
            raise ArgumentError, "flake_records must be an Array" unless flake_records.is_a?(Array)

            results_by_run = group_by_run(all_results)

            flake_records.map do |record|
              causes = build_root_causes(record, flake_records, results_by_run)
              causes = [unknown_cause] if causes.empty?
              rebuild_record(record, causes)
            end
          end

          private

          def rebuild_record(record, causes)
            Models::FlakeRecord.new(
              test_identity: record.test_identity,
              results: record.results,
              root_causes: causes,
              first_seen: record.first_seen,
              last_seen: record.last_seen
            )
          end

          def group_by_run(all_results)
            all_results.each_with_object({}) do |result, hash|
              hash[result.run_id] ||= []
              hash[result.run_id] << result
            end
          end

          def build_root_causes(record, all_records, results_by_run)
            [
              timing_cause(record),
              shared_state_cause(record, all_records),
              external_dependency_cause(record),
              random_seed_cause(record),
              resource_contention_cause(record, results_by_run),
              timezone_locale_cause(record)
            ].select { |c| c.confidence >= CONFIDENCE_THRESHOLD }
             .sort_by { |c| -c.confidence }
          end

          def timing_cause(record)
            score = timing_signal(record)
            Models::RootCause.new(
              category: :timing_dependent,
              confidence: score,
              evidence: timing_evidence(record, score),
              description: "High duration variance suggests timing-sensitive behavior"
            )
          end

          def shared_state_cause(record, all_records)
            score = shared_state_signal(record, all_records)
            n = count_same_file_flakes(record, all_records)
            Models::RootCause.new(
              category: :shared_state,
              confidence: score,
              evidence: ["#{n} other flakes in same file"],
              description: "Multiple flakes in same file/context suggest shared state contamination"
            )
          end

          def external_dependency_cause(record)
            score = external_dependency_signal(record)
            Models::RootCause.new(
              category: :external_dependency,
              confidence: score,
              evidence: external_evidence(record),
              description: "Error messages reference external services or network"
            )
          end

          def random_seed_cause(record)
            score = random_seed_signal(record)
            Models::RootCause.new(
              category: :random_seed,
              confidence: score,
              evidence: seed_evidence(record),
              description: "Different random seeds correlate with different test outcomes"
            )
          end

          def resource_contention_cause(record, results_by_run)
            score = resource_contention_signal(record, results_by_run)
            Models::RootCause.new(
              category: :resource_contention,
              confidence: score,
              evidence: ["Failures cluster in runs with multiple other failures"],
              description: "Failures co-occur with high failure counts suggesting resource pressure"
            )
          end

          def timezone_locale_cause(record)
            score = timezone_locale_signal(record)
            Models::RootCause.new(
              category: :timezone_locale,
              confidence: score,
              evidence: timezone_evidence(record),
              description: "Error messages reference time zones, locales, or date parsing"
            )
          end

          def unknown_cause
            Models::RootCause.new(
              category: :unknown,
              confidence: 0.5,
              evidence: ["No specific signal matched"],
              description: "Unable to determine root cause from available signals"
            )
          end

          def timing_evidence(record, score)
            return [] if score < CONFIDENCE_THRESHOLD

            durations = record.durations
            return [] if durations.empty?

            mean = durations.sum / durations.size.to_f
            ["Duration variance: #{record.duration_variance.round(1)}ms, mean: #{mean.round(1)}ms"]
          end

          def external_evidence(record)
            record.results
                  .filter_map(&:error_message)
                  .select { |m| SignalExtractors::EXTERNAL_PATTERNS.any? { |p| p.match?(m) } }
                  .first(3)
          end

          def seed_evidence(record)
            seeds = record.results.filter_map { |r| r.metadata[:seed] }
            return [] if seeds.empty?

            ["Seeds observed: #{seeds.uniq.first(5).join(", ")}"]
          end

          def timezone_evidence(record)
            record.results
                  .filter_map(&:error_message)
                  .select { |m| SignalExtractors::TIMEZONE_PATTERNS.any? { |p| p.match?(m) } }
                  .first(3)
          end

          def count_same_file_flakes(record, all_records)
            all_records.count do |fr|
              fr != record && fr.test_identity.file_path == record.test_identity.file_path
            end
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
