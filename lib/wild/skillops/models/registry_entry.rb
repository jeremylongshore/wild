# frozen_string_literal: true

module Wild
  module Skillops
    module Models
      # A full registry entry combining a skill with its associated metadata.
      # This is the canonical read-side view of a skill in the registry.
      class RegistryEntry
        attr_reader :skill, :versions, :health_status, :owner, :dependencies

        def initialize(skill:, versions: [], health_status: nil, owner: nil, dependencies: [])
          raise ValidationError, "skill must be a Skill instance" unless skill.is_a?(Skill)

          @skill         = skill
          @versions      = versions
          @health_status = health_status
          @owner         = owner
          @dependencies  = dependencies
        end

        delegate :name, to: :@skill

        def current_version
          @skill.version
        end

        delegate :lifecycle_state, to: :@skill

        def healthy?
          @health_status&.state == :available
        end

        def to_h
          {
            skill: @skill.to_h,
            versions: @versions.map(&:to_h),
            health_status: @health_status&.to_h,
            owner: @owner&.to_h,
            dependencies: @dependencies.map(&:to_h)
          }
        end
      end
    end
  end
end
