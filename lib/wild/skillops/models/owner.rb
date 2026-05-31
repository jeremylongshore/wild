# frozen_string_literal: true

module Wild
  module Skillops
    module Models
      # Captures ownership metadata for a registered skill.
      class Owner
        attr_reader :skill_name, :team, :contact

        def initialize(skill_name:, team:, contact: nil)
          raise ValidationError, "skill_name must be a non-empty String" unless valid_string?(skill_name)
          raise ValidationError, "team must be a non-empty String" unless valid_string?(team)
          raise ValidationError, "contact must be a String or nil" if contact && !contact.is_a?(String)

          @skill_name = skill_name.strip
          @team       = team.strip
          @contact    = contact
        end

        def to_h
          { skill_name: @skill_name, team: @team, contact: @contact }
        end

        private

        def valid_string?(value)
          value.is_a?(String) && !value.strip.empty?
        end
      end
    end
  end
end
