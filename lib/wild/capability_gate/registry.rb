# frozen_string_literal: true

module Wild
  module CapabilityGate
    # In-memory registry of capability definitions.
    #
    # Loaded from YAML at initialization. Immutable after construction.
    # Provides lookup by name and list-all for discovery.
    # See 002-AT-STND-capability-model.md and 004-AT-ADEC-architecture-decisions.md (Decision 5).
    class Registry
      class DuplicateCapabilityError < StandardError; end

      require_relative "registry/config_loader"

      def self.from_file(path)
        capabilities = ConfigLoader.load_file(path)
        new(capabilities)
      end

      def initialize(capabilities)
        @capabilities = build_index(capabilities)
        freeze
      end

      # Look up a capability by name. Returns nil if not found.
      def find(name)
        @capabilities[name.to_sym]
      end

      # Look up a capability by name. Raises KeyError if not found.
      def fetch(name)
        sym = name.to_sym
        @capabilities.fetch(sym) { raise KeyError, "unknown capability: #{sym.inspect}" }
      end

      # Returns true if a capability with the given name exists.
      def known?(name)
        @capabilities.key?(name.to_sym)
      end

      # Returns all registered capabilities as an array. Read-only.
      def all
        @capabilities.values
      end

      # Returns all registered capability names.
      def names
        @capabilities.keys
      end

      delegate :size, to: :@capabilities

      private

      def build_index(capabilities)
        index = {}
        capabilities.each do |cap|
          if index.key?(cap.name)
            raise DuplicateCapabilityError,
                  "duplicate capability name: #{cap.name.inspect}"
          end

          index[cap.name] = cap
        end
        index.freeze
      end
    end
  end
end
