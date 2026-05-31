# frozen_string_literal: true

module Wild
  module Skillops
    module Discovery
      # Full-text-ish search across skills using substring matching.
      # Scores results by number of field matches for relevance ordering.
      class SearchEngine
        FIELD_WEIGHTS = {
          name: 3,
          tags: 2,
          description: 1
        }.freeze

        def initialize(finder:)
          @finder = finder
        end

        # Returns entries matching query, ordered by relevance score descending.
        def search(query)
          return [] if query.nil? || query.strip.empty?

          q = query.strip.downcase
          scored = @finder.all.filter_map do |entry|
            score = relevance_score(entry, q)
            score.positive? ? [entry, score] : nil
          end

          scored.sort_by { |_, s| -s }.map(&:first)
        end

        # Search within a specific category.
        def search_in_category(query, category)
          search(query).select { |e| e.skill.category == category.to_sym }
        end

        # Search within a specific repo.
        def search_in_repo(query, repo)
          search(query).select { |e| e.skill.repo == repo }
        end

        private

        def relevance_score(entry, query)
          skill  = entry.skill
          score  = 0
          score += FIELD_WEIGHTS[:name] if skill.name.downcase.include?(query)
          score += FIELD_WEIGHTS[:tags] if skill.tags.any? { |t| t.include?(query) }
          score += FIELD_WEIGHTS[:description] if skill.description.downcase.include?(query)
          score
        end
      end
    end
  end
end
