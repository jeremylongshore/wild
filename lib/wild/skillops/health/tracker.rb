# frozen_string_literal: true

module Wild
  module Skillops
    module Health
      # Records and updates health status for skills in the registry.
      class Tracker
        def initialize(store:)
          @store = store
        end

        # Record or update health status for a skill.
        def record(skill_name, state:, message: nil, checked_at: nil)
          entry = @store.fetch(skill_name)
          hs = Models::HealthStatus.new(
            skill_name: skill_name,
            state: state,
            last_checked_at: checked_at || Time.now.utc,
            message: message
          )
          updated = Models::RegistryEntry.new(
            skill: entry.skill,
            versions: entry.versions,
            health_status: hs,
            owner: entry.owner,
            dependencies: entry.dependencies
          )
          @store.add(updated)
          hs
        end

        def status_for(skill_name)
          @store.fetch(skill_name).health_status
        end

        def stale?(skill_name)
          hs = status_for(skill_name)
          return false if hs.nil?

          hs.stale?
        end
      end
    end
  end
end
