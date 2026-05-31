# frozen_string_literal: true

module Wild
  module Skillops
    module Health
      # Aggregates health data across the entire registry.
      class Aggregator
        def initialize(store:)
          @store = store
        end

        # Returns a summary Hash of health states across all skills.
        # rubocop:disable Metrics/AbcSize -- aggregation over 4 state buckets + counts
        def summary
          all_statuses = @store.all.filter_map(&:health_status)
          counts = Hash.new(0)
          Wild.config.skillops.allowed_health_states.each { |s| counts[s] = 0 }
          all_statuses.each { |hs| counts[hs.state] += 1 }

          {
            total_skills: @store.size,
            tracked: all_statuses.size,
            untracked: @store.size - all_statuses.size,
            counts: counts,
            stale_count: all_statuses.count(&:stale?)
          }
        end
        # rubocop:enable Metrics/AbcSize

        # Returns entries with no health status recorded.
        def untracked_entries
          @store.all.select { |e| e.health_status.nil? }
        end

        # Returns entries whose health is stale.
        def stale_entries
          @store.all.select { |e| e.health_status&.stale? }
        end

        # Returns entries with a specific health state.
        def entries_by_state(state)
          sym = state.to_sym
          @store.all.select { |e| e.health_status&.state == sym }
        end
      end
    end
  end
end
