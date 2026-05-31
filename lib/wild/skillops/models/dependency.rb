# frozen_string_literal: true

module Wild
  module Skillops
    module Models
      # Represents a dependency relationship between two skills.
      class Dependency
        DEPENDENCY_TYPES = %i[required optional].freeze

        attr_reader :skill_name, :depends_on, :dependency_type, :description

        def initialize(skill_name:, depends_on:, dependency_type: :required, description: nil)
          raise ValidationError, "skill_name must be a non-empty String" unless valid_string?(skill_name)
          raise ValidationError, "depends_on must be a non-empty String" unless valid_string?(depends_on)

          type = dependency_type.to_sym
          unless DEPENDENCY_TYPES.include?(type)
            raise ValidationError, "dependency_type must be one of #{DEPENDENCY_TYPES.join(", ")}"
          end
          raise ValidationError, "description must be a String or nil" if description && !description.is_a?(String)

          @skill_name      = skill_name.strip
          @depends_on      = depends_on.strip
          @dependency_type = type
          @description     = description
        end

        def to_h
          {
            skill_name: @skill_name,
            depends_on: @depends_on,
            dependency_type: @dependency_type,
            description: @description
          }
        end

        private

        def valid_string?(value)
          value.is_a?(String) && !value.strip.empty?
        end
      end
    end
  end
end
