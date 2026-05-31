# frozen_string_literal: true

module Wild
  module Skillops
    module Registry
      # Handles registration, updates, deprecation, and retirement of skills.
      class Registrar
        def initialize(store:, version_manager:, lifecycle_manager:, tag_index:)
          @store             = store
          @version_manager   = version_manager
          @lifecycle_manager = lifecycle_manager
          @tag_index         = tag_index
        end

        # Register a new skill. Raises DuplicateSkillError if name already registered.
        def register(skill)
          raise ValidationError, "skill must be a Models::Skill instance" unless skill.is_a?(Models::Skill)
          raise DuplicateSkillError, "Skill '#{skill.name}' is already registered" if @store.include?(skill.name)

          entry = Models::RegistryEntry.new(skill: skill)
          @store.add(entry)
          @version_manager.record_version(skill.name, skill.version, changes: ["Initial registration"])
          @tag_index.index(skill.name, skill.tags)
          entry
        end

        # Update attributes of an existing skill. Returns the updated entry.
        def update(skill_name, attrs)
          entry  = @store.fetch(skill_name)
          skill  = entry.skill
          new_skill = rebuild_skill(skill, attrs)
          changes = compute_changes(skill, new_skill)
          updated_entry = Models::RegistryEntry.new(
            skill: new_skill,
            versions: entry.versions,
            health_status: entry.health_status,
            owner: entry.owner,
            dependencies: entry.dependencies
          )
          @store.add(updated_entry)
          @version_manager.record_version(skill_name, new_skill.version, changes: changes) unless changes.empty?
          @tag_index.reindex(skill_name, old_tags: skill.tags, new_tags: new_skill.tags)
          updated_entry
        end

        # Deprecate a skill. Transition: active -> deprecated.
        def deprecate(skill_name, reason: "Deprecated")
          entry = @store.fetch(skill_name)
          new_skill = transition_skill(entry.skill, :deprecated)
          updated = replace_skill_in_entry(entry, new_skill)
          @version_manager.record_version(skill_name, new_skill.version, changes: ["Deprecated: #{reason}"])
          updated
        end

        # Retire a skill. Transition: deprecated -> retired.
        def retire(skill_name)
          entry = @store.fetch(skill_name)
          new_skill = transition_skill(entry.skill, :retired)
          updated = replace_skill_in_entry(entry, new_skill)
          @version_manager.record_version(skill_name, new_skill.version, changes: ["Retired"])
          updated
        end

        private

        def rebuild_skill(skill, attrs)
          Models::Skill.new(
            name: skill.name,
            description: attrs.fetch(:description, skill.description),
            repo: attrs.fetch(:repo, skill.repo),
            version: attrs.fetch(:version, skill.version),
            tags: attrs.fetch(:tags, skill.tags),
            category: attrs.fetch(:category, skill.category),
            capabilities_required: attrs.fetch(:capabilities_required, skill.capabilities_required),
            lifecycle_state: attrs.fetch(:lifecycle_state, skill.lifecycle_state),
            registered_at: skill.registered_at
          )
        end

        def transition_skill(skill, target_state)
          @lifecycle_manager.transition!(skill.lifecycle_state, target_state)
          Models::Skill.new(
            name: skill.name,
            description: skill.description,
            repo: skill.repo,
            version: skill.version,
            tags: skill.tags,
            category: skill.category,
            capabilities_required: skill.capabilities_required,
            lifecycle_state: target_state,
            registered_at: skill.registered_at
          )
        end

        def replace_skill_in_entry(entry, new_skill)
          updated = Models::RegistryEntry.new(
            skill: new_skill,
            versions: entry.versions,
            health_status: entry.health_status,
            owner: entry.owner,
            dependencies: entry.dependencies
          )
          @store.add(updated)
          updated
        end

        # rubocop:disable Metrics/AbcSize -- 5 simple field diffs
        def compute_changes(old_skill, new_skill)
          changes = []
          changes << "description changed" if old_skill.description != new_skill.description
          changes << "version bumped to #{new_skill.version}" if old_skill.version != new_skill.version
          changes << "tags updated" if old_skill.tags.sort != new_skill.tags.sort
          changes << "category changed to #{new_skill.category}" if old_skill.category != new_skill.category
          changes << "repo changed to #{new_skill.repo}" if old_skill.repo != new_skill.repo
          changes
        end
        # rubocop:enable Metrics/AbcSize
      end
    end
  end
end
