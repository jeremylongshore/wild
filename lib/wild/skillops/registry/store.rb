# frozen_string_literal: true

module Wild
  module Skillops
    module Registry
      # In-memory store for registry entries.
      #
      # Enforces capacity limits. Single-process, non-concurrent: it makes no
      # atomicity, durability, or thread-safety guarantees beyond whatever
      # Ruby's Hash already provides. #add is a plain check-then-set (read
      # @entries.size, then write) with no Mutex/Monitor guarding it, so two
      # callers racing near max_skills can both pass the capacity check
      # before either mutation lands. Per council F5 / package.yml: "NO
      # atomicity, NO durability claims."
      class Store
        def initialize
          @entries = {}
        end

        def add(entry)
          raise ValidationError, "entry must be a Models::RegistryEntry" unless entry.is_a?(Models::RegistryEntry)

          max = Wild.config.skillops.max_skills
          if @entries.size >= max && !@entries.key?(entry.name)
            raise RegistryCapacityError, "Registry capacity of #{max} skills exceeded"
          end

          @entries[entry.name] = entry
        end

        def fetch(name)
          @entries.fetch(name) { raise NotFoundError, "Skill '#{name}' not found in registry" }
        end

        def fetch_or_nil(name)
          @entries[name]
        end

        def include?(name)
          @entries.key?(name)
        end

        def all
          @entries.values.dup
        end

        delegate :delete, to: :@entries

        delegate :size, to: :@entries

        delegate :clear, to: :@entries

        def names
          @entries.keys.dup
        end
      end
    end
  end
end
