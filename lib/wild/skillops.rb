# frozen_string_literal: true

# Wild::Skillops — Tier 2 per ADR-0003. In-memory registry and discovery layer
# for skills/capabilities across the Wild ecosystem.
#
# Per council rev2 §F5 (Lamport-caught lie about "atomic" durability claims;
# Cunningham, Armstrong, DHH, Hickey, Beck, Fowler concur), this namespace
# is **internal by default** — `Wild.config.skillops.enabled` defaults to
# `false` (per PR-B). External consumers wait for an ADR-0002 path; until
# then, treat this namespace's public API as unstable. For the actual
# atomicity/durability/thread-safety guarantee (and lack thereof), see
# `Registry::Store`'s class comment (`lib/wild/skillops/registry/store.rb`)
# and `package.yml` (`lib/wild/skillops/package.yml`) — those two are the
# single source of truth for the F5 wording; this header does not restate it.
#
# Code moved from the old wild-skillops-registry gem in Role 5 PR-5.

# Models
require "wild/skillops/models/skill"
require "wild/skillops/models/skill_version"
require "wild/skillops/models/dependency"
require "wild/skillops/models/health_status"
require "wild/skillops/models/owner"
require "wild/skillops/models/registry_entry"

# Registry
require "wild/skillops/registry/store"
require "wild/skillops/registry/registrar"
require "wild/skillops/registry/finder"

# Versioning
require "wild/skillops/versioning/version_manager"
require "wild/skillops/versioning/changelog_builder"

# Health
require "wild/skillops/health/tracker"
require "wild/skillops/health/aggregator"

# Governance
require "wild/skillops/governance/lifecycle_manager"
require "wild/skillops/governance/ownership_resolver"

# Discovery
require "wild/skillops/discovery/tag_index"
require "wild/skillops/discovery/search_engine"

# Export — flagged by PR-E coupling survey for F6 wire-or-delete audit
# under wild-rvv.8.3. Required here to preserve test coverage during the
# structure move; behavior decision deferred to that bead.
require "wild/skillops/export/json_exporter"
require "wild/skillops/export/markdown_exporter"

module Wild
  module Skillops
    # Build a fully-wired registry instance. Returns a RegistryFacade
    # exposing all subsystems through one object.
    #
    # Skillops is internal until a consumer deliberately opts in. Keeping this
    # guard at the public factory—not at file require time—lets the rest of
    # Wild boot normally while making the F5 default operational.
    def self.build
      unless Wild.config.skillops.enabled
        raise DisabledError,
              "Wild::Skillops is disabled by default; set Wild.config.skillops.enabled = true to opt in"
      end

      store     = Registry::Store.new
      tag_index = Discovery::TagIndex.new
      RegistryFacade.new(**build_components(store, tag_index))
    end

    # @api private
    # rubocop:disable Metrics/MethodLength -- 13-component DI wiring, mechanical
    def self.build_components(store, tag_index)
      lifecycle_manager = Governance::LifecycleManager.new
      version_manager   = Versioning::VersionManager.new(store: store)
      registrar = Registry::Registrar.new(
        store: store,
        version_manager: version_manager,
        lifecycle_manager: lifecycle_manager,
        tag_index: tag_index
      )
      {
        store: store,
        tag_index: tag_index,
        registrar: registrar,
        finder: Registry::Finder.new(store: store, tag_index: tag_index),
        version_manager: version_manager,
        changelog_builder: Versioning::ChangelogBuilder.new(version_manager: version_manager),
        health_tracker: Health::Tracker.new(store: store),
        health_aggregator: Health::Aggregator.new(store: store),
        lifecycle_manager: lifecycle_manager,
        ownership_resolver: Governance::OwnershipResolver.new(store: store),
        search_engine: Discovery::SearchEngine.new(
          finder: Registry::Finder.new(store: store, tag_index: tag_index)
        ),
        json_exporter: Export::JsonExporter.new(store: store),
        markdown_exporter: Export::MarkdownExporter.new(store: store)
      }
    end
    # rubocop:enable Metrics/MethodLength
    private_class_method :build_components

    # Convenience facade exposing all subsystems through one object.
    class RegistryFacade
      attr_reader :store, :registrar, :finder, :version_manager,
                  :changelog_builder, :health_tracker, :health_aggregator,
                  :lifecycle_manager, :ownership_resolver, :search_engine,
                  :json_exporter, :markdown_exporter, :tag_index

      def initialize(**kwargs)
        kwargs.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end
    end
  end
end
