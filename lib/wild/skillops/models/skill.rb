# frozen_string_literal: true

require "time"

module Wild
  module Skillops
    module Models
      # Represents a single skill/capability entry in the registry.
      # A skill is the canonical unit of registration — globally unique by name.
      class Skill
        VALID_CATEGORIES = %i[
          introspection admin telemetry analysis workflow governance
        ].freeze

        attr_reader :name,
                    :description,
                    :repo,
                    :version,
                    :tags,
                    :category,
                    :capabilities_required,
                    :lifecycle_state,
                    :registered_at

        # rubocop:disable Metrics/ParameterLists -- 9-attr domain model
        def initialize(name:, description:, repo:, version:,
                       tags: [], category: :workflow,
                       capabilities_required: [], lifecycle_state: :draft,
                       registered_at: nil)
          # rubocop:enable Metrics/ParameterLists
          @name                 = validate_name!(name)
          @description          = validate_string!(description, "description")
          @repo                 = validate_string!(repo, "repo")
          @version              = validate_version!(version)
          @tags                 = validate_tags!(tags)
          @category             = validate_category!(category)
          @capabilities_required = validate_string_array!(capabilities_required, "capabilities_required")
          @lifecycle_state      = lifecycle_state.to_sym
          @registered_at        = registered_at || Time.now.utc
        end

        def to_h
          {
            name: @name,
            description: @description,
            repo: @repo,
            version: @version,
            tags: @tags,
            category: @category,
            capabilities_required: @capabilities_required,
            lifecycle_state: @lifecycle_state,
            registered_at: @registered_at.iso8601
          }
        end

        def ==(other)
          other.is_a?(Skill) && other.name == @name
        end

        private

        def validate_name!(value)
          raise ValidationError, "name must be a non-empty String" unless value.is_a?(String) && !value.strip.empty?

          value.strip
        end

        def validate_string!(value, field)
          raise ValidationError, "#{field} must be a non-empty String" unless value.is_a?(String) && !value.strip.empty?

          value.strip
        end

        def validate_version!(value)
          raise ValidationError, "version must be a non-empty String" unless value.is_a?(String) && !value.strip.empty?
          raise ValidationError, "version must follow semver (x.y.z)" unless value.match?(/\A\d+\.\d+\.\d+/)

          value.strip
        end

        def validate_tags!(value)
          raise ValidationError, "tags must be an Array" unless value.is_a?(Array)
          raise ValidationError, "tags must contain only Strings" unless value.all?(String)

          value.map(&:strip).map(&:downcase)
        end

        def validate_category!(value)
          sym = value.to_sym
          unless VALID_CATEGORIES.include?(sym)
            raise ValidationError, "category must be one of #{VALID_CATEGORIES.join(", ")}"
          end

          sym
        end

        def validate_string_array!(value, field)
          raise ValidationError, "#{field} must be an Array" unless value.is_a?(Array)
          raise ValidationError, "#{field} must contain only Strings" unless value.all?(String)

          value
        end
      end
    end
  end
end
