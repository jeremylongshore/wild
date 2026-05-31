# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Analysis
        module SignalExtractors
          EXTERNAL_PATTERNS = [
            /network/i, /connection\s+refused/i, /timeout/i, /http/i,
            /database/i, /db\s+error/i, /api/i, /socket/i, /dns/i,
            /connection\s+reset/i, /ECONNREFUSED/i, /Net::/
          ].freeze

          TIMEZONE_PATTERNS = [
            /time\s+zone/i, /timezone/i, /locale/i, /utc/i,
            /dst/i, /daylight/i, /strftime/i, /strptime/i,
            /ActiveSupport::TimeZone/i, /date.*mismatch/i
          ].freeze

          SEED_PATTERNS = [
            /seed/i, /random/i, /Faker/i, /SecureRandom/i, /rand\b/
          ].freeze

          def timing_signal(flake_record)
            durations = flake_record.durations
            return 0.0 if durations.size < 2

            variance = flake_record.duration_variance
            mean = durations.sum / durations.size.to_f
            return 0.0 if mean.zero?

            coefficient_of_variation = variance / mean
            normalize_score([coefficient_of_variation * 1.5, 1.0].min)
          end

          def shared_state_signal(flake_record, all_flake_records)
            id = flake_record.test_identity
            file_score = file_sharing_score(id, all_flake_records, flake_record)
            context_score = context_sharing_score(id, all_flake_records, flake_record)
            normalize_score([file_score, context_score].max)
          end

          def external_dependency_signal(flake_record)
            error_messages = flake_record.results.filter_map(&:error_message)
            return 0.0 if error_messages.empty?

            matches = error_messages.count { |msg| EXTERNAL_PATTERNS.any? { |pat| pat.match?(msg) } }
            normalize_score(matches.to_f / error_messages.size)
          end

          # rubocop:disable Metrics/AbcSize
          def random_seed_signal(flake_record)
            seeds = flake_record.results.filter_map { |r| r.metadata[:seed] }
            return check_error_messages_for_seed(flake_record) if seeds.empty?

            return 0.0 if seeds.uniq.size <= 1

            failure_seeds = seeds_for_status(flake_record, :failed)
            pass_seeds = seeds_for_status(flake_record, :passed)
            overlap = (failure_seeds & pass_seeds).size

            return 0.8 if overlap.zero? && failure_seeds.any? && pass_seeds.any?

            normalize_score(0.3)
          end
          # rubocop:enable Metrics/AbcSize

          def resource_contention_signal(flake_record, all_results_by_run)
            failure_run_ids = flake_record.results.select(&:failed?).map(&:run_id)
            return 0.0 if failure_run_ids.empty?

            counts = failure_run_failure_counts(failure_run_ids, all_results_by_run)
            return 0.0 if counts.empty?

            avg = counts.sum.to_f / counts.size
            normalize_score([avg * 0.05, 0.7].min)
          end

          def timezone_locale_signal(flake_record)
            error_messages = flake_record.results.filter_map(&:error_message)
            return 0.0 if error_messages.empty?

            matches = error_messages.count { |msg| TIMEZONE_PATTERNS.any? { |pat| pat.match?(msg) } }
            normalize_score(matches.to_f / error_messages.size)
          end

          private

          def file_sharing_score(identity, records, excluded)
            n = count_matching(records, excluded) { |fr| fr.test_identity.file_path == identity.file_path }
            [n * 0.2, 0.6].min
          end

          def context_sharing_score(identity, records, excluded)
            n = count_matching(records, excluded) do |fr|
              !fr.test_identity.context.empty? && fr.test_identity.context == identity.context
            end
            [n * 0.3, 0.9].min
          end

          def count_matching(records, excluded, &block)
            records.count { |fr| fr != excluded && block.call(fr) }
          end

          def seeds_for_status(flake_record, status_check)
            flake_record.results
                        .select { |r| status_check == :failed ? r.failed? : r.passed? }
                        .filter_map { |r| r.metadata[:seed] }
                        .uniq
          end

          def failure_run_failure_counts(run_ids, results_by_run)
            run_ids.filter_map do |run_id|
              run_results = results_by_run[run_id]
              next unless run_results

              run_results.count(&:failed?)
            end
          end

          def check_error_messages_for_seed(flake_record)
            error_messages = flake_record.results.filter_map(&:error_message)
            return 0.0 if error_messages.empty?

            matches = error_messages.count { |msg| SEED_PATTERNS.any? { |pat| pat.match?(msg) } }
            normalize_score(matches.to_f / error_messages.size * 0.5)
          end

          def normalize_score(value)
            value.to_f.clamp(0.0, 1.0).round(4)
          end
        end
      end
    end
  end
end
