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

      require "digest"
      require_relative "registry/config_loader"

      # Sentinel policy_version for a registry constructed without a fingerprint
      # (e.g. tests using Registry.new directly). Matches the audit_event.yml
      # policy_version pattern so events stay schema-valid; the all-zero hash
      # signals "policy provenance unavailable".
      UNKNOWN_POLICY_VERSION = "capabilities.yml@sha256:#{"0" * 64}".freeze

      # Fingerprint of the PARSED + normalized capability set used for every
      # audit event's policy_version (F2 replay; wild-rvv.4.1.3). Computed over
      # the parsed content, NOT the file bytes — a comment/whitespace edit must
      # not change the version. Resolved once at load and frozen, so reading it
      # on the audit (incl. rescue) path never does I/O and never raises.
      attr_reader :policy_version

      def self.from_file(path)
        capabilities = ConfigLoader.load_file(path)
        new(capabilities, policy_version: fingerprint(capabilities))
      end

      # Deterministic SHA-256 over the canonicalized capability set: sort by
      # name, serialize each capability's policy-meaningful fields (name,
      # risk_level, prerequisites as sorted [type, sorted-params]) in a stable
      # order. Reformatting the YAML does not change this; changing a capability
      # does. Serializes content, never object identity, so it is reproducible
      # across loads.
      def self.fingerprint(capabilities)
        canonical = capabilities.map { |cap| canonical_capability(cap) }.sort_by(&:first)
        "capabilities.yml@sha256:#{Digest::SHA256.hexdigest(canonical.inspect)}"
      end

      def self.canonical_capability(cap)
        prereqs = Array(cap.prerequisites).map { |p| canonical_prerequisite(p) }.sort
        [cap.name.to_s, cap.risk_level.to_s, prereqs]
      end

      def self.canonical_prerequisite(prereq)
        params = Hash(prereq.params).sort_by { |k, _| k.to_s }.map { |k, v| [k.to_s, v.to_s] }
        [prereq.type.to_s, params]
      end

      def initialize(capabilities, policy_version: UNKNOWN_POLICY_VERSION)
        @capabilities = build_index(capabilities)
        @policy_version = policy_version
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
