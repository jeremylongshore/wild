# frozen_string_literal: true

module Wild
  module Skillops
    module Registry
      # In-memory store for registry entries.
      #
      # Enforces capacity limits. This class provides no atomicity, durability,
      # or thread-safety guarantees of its own: it is the CALLER's obligation
      # to serialize access. `000-docs/005` (the engine spec) scopes that
      # obligation explicitly to a single-process, non-concurrent caller; a
      # threaded Puma worker calling into this store from more than one
      # thread is out of the supported contract. Ruby's own `Hash` carries no
      # thread-safety contract either: on CRuby the GVL makes individual
      # Hash operations *look* safe, but that is an implementation detail,
      # not a promise, and JRuby's Hash raises `ConcurrentModificationError`
      # under the same access pattern.
      #
      # The real check-then-set (TOCTOU) races live one level up, in the
      # callers that read this store and write back a derived value without
      # a lock: `Registrar#register` (`include?` then `add`),
      # `Registrar#update` (`fetch`, rebuild, `add`), `Health::Tracker`
      # (`fetch`, rebuild, `add`), `Governance::OwnershipResolver` (`fetch`,
      # rebuild, `add`), and `Discovery::TagIndex#index`/`#reindex` (`<<
      # unless include?`). `Store#add` itself is just the last link in each
      # of those chains, not the sole race. Per council F5 / package.yml:
      # "NO atomicity, NO durability claims."
      #
      # Monitor-vs-document is an open owner decision; see the bead "Decide
      # whether the skillops registry store gets a Monitor or stays
      # documented as caller-synchronized."
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
