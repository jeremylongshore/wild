# frozen_string_literal: true

require "time"

module Wild
  module Skillops
    module Models
      # Tracks the current health state of a skill.
      class HealthStatus
        attr_reader :skill_name, :state, :last_checked_at, :message

        def initialize(skill_name:, state:, last_checked_at: nil, message: nil)
          raise ValidationError, "skill_name must be a non-empty String" unless valid_string?(skill_name)

          sym = state.to_sym
          allowed = Wild.config.skillops.allowed_health_states
          raise ValidationError, "state must be one of #{allowed.join(", ")}" unless allowed.include?(sym)

          raise ValidationError, "message must be a String or nil" if message && !message.is_a?(String)

          @skill_name      = skill_name.strip
          @state           = sym
          @last_checked_at = last_checked_at || Time.now.utc
          @message         = message
        end

        def stale?
          threshold = Wild.config.skillops.health_stale_threshold_hours
          (Time.now.utc - @last_checked_at) > (threshold * 3600)
        end

        def to_h
          {
            skill_name: @skill_name,
            state: @state,
            last_checked_at: @last_checked_at.iso8601,
            message: @message,
            stale: stale?
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
