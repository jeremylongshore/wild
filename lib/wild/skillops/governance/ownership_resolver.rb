# frozen_string_literal: true

module Wild
  module Skillops
    module Governance
      # Resolves and manages skill ownership. Ownership is stored per-skill
      # inside the RegistryEntry and mutated through this resolver.
      class OwnershipResolver
        def initialize(store:)
          @store = store
        end

        # Assign or replace the owner for a skill.
        def assign(skill_name, team:, contact: nil)
          entry = @store.fetch(skill_name)
          owner = Models::Owner.new(skill_name: skill_name, team: team, contact: contact)
          updated = Models::RegistryEntry.new(
            skill: entry.skill,
            versions: entry.versions,
            health_status: entry.health_status,
            owner: owner,
            dependencies: entry.dependencies
          )
          @store.add(updated)
          owner
        end

        def owner_for(skill_name)
          @store.fetch(skill_name).owner
        end

        # Returns all entries that have no assigned owner.
        def unowned_entries(store_ref = nil)
          src = store_ref || @store
          src.all.select { |e| e.owner.nil? }
        end

        # Returns all entries owned by a given team.
        def entries_for_team(team)
          @store.all.select { |e| e.owner&.team == team }
        end
      end
    end
  end
end
