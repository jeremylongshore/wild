# frozen_string_literal: true

module Wild
  module Skillops
    module Versioning
      # Tracks skill version history and detects changes.
      class VersionManager
        def initialize(store:)
          @store    = store
          @versions = Hash.new { |h, k| h[k] = [] }
        end

        # Record a new version snapshot for a skill.
        def record_version(skill_name, version, changes: [])
          existing_entry = @store.fetch_or_nil(skill_name)
          raise NotFoundError, "Skill '#{skill_name}' not found" unless existing_entry

          max = Wild.config.skillops.max_versions_per_skill
          if @versions[skill_name].size >= max
            raise VersionCapacityError,
                  "Skill '#{skill_name}' has reached the version limit of #{max}"
          end

          sv = Models::SkillVersion.new(
            skill_name: skill_name,
            version: version,
            changes: changes
          )
          @versions[skill_name] << sv
          sv
        end

        def versions_for(skill_name)
          @versions[skill_name].dup
        end

        def latest_version(skill_name)
          @versions[skill_name].last
        end

        def version_count(skill_name)
          @versions[skill_name].size
        end

        def all_versions
          @versions.transform_values(&:dup)
        end
      end
    end
  end
end
