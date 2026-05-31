# frozen_string_literal: true

module Wild
  module Skillops
    module Discovery
      # Inverted index mapping normalized tags to skill names for O(1) tag lookup.
      class TagIndex
        def initialize
          @index = Hash.new { |h, k| h[k] = [] }
        end

        def index(skill_name, tags)
          tags.each do |tag|
            normalized = normalize(tag)
            @index[normalized] << skill_name unless @index[normalized].include?(skill_name)
          end
        end

        # Remove old tags and add new tags for a skill.
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity -- 4-step diff is intentional
        def reindex(skill_name, old_tags:, new_tags:)
          removed = old_tags.map { |t| normalize(t) } - new_tags.map { |t| normalize(t) }
          added   = new_tags.map { |t| normalize(t) } - old_tags.map { |t| normalize(t) }

          removed.each { |tag| @index[tag].delete(skill_name) }
          added.each do |tag|
            @index[tag] << skill_name unless @index[tag].include?(skill_name)
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

        def lookup(tag)
          @index[normalize(tag)].dup
        end

        def all_tags
          @index.keys.sort
        end

        def remove_skill(skill_name)
          @index.each_value { |names| names.delete(skill_name) }
        end

        private

        def normalize(tag)
          tag.to_s.strip.downcase
        end
      end
    end
  end
end
