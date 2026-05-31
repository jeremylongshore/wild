# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module History
        class Store
          def initialize(max_entries: nil)
            config = Wild.config.analyzers.test_flakes
            @max_entries = max_entries || config.max_history_entries
            @records = {}
            @snapshots = {}
          end

          def record(flake_record)
            key = flake_record.test_identity.key
            existing = @records[key]

            if existing
              merged = merge_records(existing, flake_record)
              @records[key] = merged
            else
              @records[key] = flake_record
            end

            snapshot!(key, flake_record.flake_rate)
            enforce_limit!
            @records[key]
          end

          def fetch(test_identity)
            @records[test_identity.key]
          end

          def all
            @records.values.dup
          end

          def trend_for(test_identity)
            key = test_identity.key
            snaps = @snapshots[key]
            return :stable unless snaps && snaps.size >= 2

            History::TrendAnalyzer.new.trend(snaps)
          end

          delegate :size, to: :@records

          def clear!
            @records.clear
            @snapshots.clear
          end

          private

          # rubocop:disable Metrics/AbcSize
          def merge_records(existing, new_record)
            all_results = (existing.results + new_record.results).uniq
            first_seen = [existing.first_seen, new_record.first_seen].compact.min
            last_seen = [existing.last_seen, new_record.last_seen].compact.max
            causes = new_record.root_causes.any? ? new_record.root_causes : existing.root_causes

            Models::FlakeRecord.new(
              test_identity: existing.test_identity,
              results: all_results,
              root_causes: causes,
              first_seen: first_seen,
              last_seen: last_seen
            )
          end
          # rubocop:enable Metrics/AbcSize

          def snapshot!(key, flake_rate)
            @snapshots[key] ||= []
            @snapshots[key] << { rate: flake_rate, at: Time.now.utc }
            @snapshots[key] = @snapshots[key].last(50)
          end

          def enforce_limit!
            return if @records.size <= @max_entries

            oldest_key = @records.min_by { |_, r| r.first_seen || Time.now.utc }.first
            @records.delete(oldest_key)
            @snapshots.delete(oldest_key)
          end
        end
      end
    end
  end
end
