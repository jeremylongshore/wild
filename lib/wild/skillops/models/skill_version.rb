# frozen_string_literal: true

require "time"

module Wild
  module Skillops
    module Models
      # A versioned snapshot describing what changed at a given skill version.
      class SkillVersion
        attr_reader :skill_name, :version, :changes, :created_at

        # rubocop:disable Metrics/AbcSize -- 3 inline validations + 4 assignments
        def initialize(skill_name:, version:, changes: [], created_at: nil)
          unless skill_name.is_a?(String) && !skill_name.strip.empty?
            raise ValidationError, "skill_name must be a non-empty String"
          end
          unless version.is_a?(String) && !version.strip.empty?
            raise ValidationError, "version must be a non-empty String"
          end
          raise ValidationError, "changes must be an Array of Strings" unless valid_changes?(changes)

          @skill_name = skill_name.strip
          @version    = version.strip
          @changes    = changes
          @created_at = created_at || Time.now.utc
        end
        # rubocop:enable Metrics/AbcSize

        def to_h
          {
            skill_name: @skill_name,
            version: @version,
            changes: @changes,
            created_at: @created_at.iso8601
          }
        end

        private

        def valid_changes?(value)
          value.is_a?(Array) && value.all?(String)
        end
      end
    end
  end
end
