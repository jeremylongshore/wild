# frozen_string_literal: true

module Wild
  module Skillops
    module Registry
      # Query and discovery interface for the registry.
      # All methods return frozen arrays of RegistryEntry objects.
      class Finder
        def initialize(store:, tag_index:)
          @store     = store
          @tag_index = tag_index
        end

        def find_by_name(name)
          @store.fetch(name)
        end

        def find_by_name_or_nil(name)
          @store.fetch_or_nil(name)
        end

        def find_by_tag(tag)
          names = @tag_index.lookup(tag.to_s.downcase)
          names.filter_map { |n| @store.fetch_or_nil(n) }
        end

        def find_by_repo(repo)
          @store.all.select { |e| e.skill.repo == repo }
        end

        def find_by_category(category)
          sym = category.to_sym
          @store.all.select { |e| e.skill.category == sym }
        end

        def find_by_lifecycle(state)
          sym = state.to_sym
          @store.all.select { |e| e.skill.lifecycle_state == sym }
        end

        # Substring match on name, description, and tags.
        def search(query)
          return [] if query.nil? || query.strip.empty?

          q = query.strip.downcase
          @store.all.select { |e| entry_matches?(e, q) }
        end

        delegate :all, to: :@store

        private

        def entry_matches?(entry, query)
          skill = entry.skill
          skill.name.downcase.include?(query) ||
            skill.description.downcase.include?(query) ||
            skill.tags.any? { |t| t.include?(query) }
        end
      end
    end
  end
end
