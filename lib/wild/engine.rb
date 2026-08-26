# frozen_string_literal: true

# Rails 8.1.x is not safe to load as `require "rails/engine"` standalone:
#   1. rails/initializable.rb calls `delegate_missing_to` before active_support
#      core_ext is loaded → NoMethodError
#   2. rails/engine/configuration.rb#initialize references `ActionDispatch`
#      without requiring it → NameError on `isolate_namespace`
# The robust fix is `require "rails"` (the meta-gem loads the full transitive
# Rails environment in correct order). Any consumer mounting Wild::Engine
# already loads Rails in their app, so the heavier load isn't a net cost.
require "rails"

module Wild
  # Wild::Engine — the Rails engine entry point. `isolate_namespace Wild`
  # confines all routes, helpers, and ActiveRecord classes to the `Wild::`
  # namespace.
  #
  # Mounted by the install generator in routes.rb:
  #
  #   mount Wild::Engine, at: "/wild"
  #
  # config.after_initialize bridges the central Wild.config (set via
  # `Wild.configure { |c| ... }` in a host-app initializer) into the two
  # namespaces that still keep their own pre-consolidation configuration
  # object: Wild::AdminTools (adapter dependency-injection) and
  # Wild::Introspection (the access-policy loader). Without this bridge,
  # `Wild.config.admin_tools`/`Wild.config.introspection` are read by
  # nothing at runtime (f-l10-3, f-x1-1, f-l09-2): the two namespaces'
  # own configuration objects are what CacheExecutor/JobExecutor/
  # FlagExecutor and the introspection adapters actually consult.
  #
  # This is engine-substrate code (root package, "."; see package.yml),
  # which per ADR-0003 depends on no Wild::* namespace package. It reaches
  # Wild::AdminTools/Wild::Introspection only through their own
  # bridge_configuration! entry points (defined in lib/wild/admin_tools.rb
  # / lib/wild/introspection.rb, both root-mapped entry files per
  # packwerk.yml's exclude list) rather than reaching directly into either
  # namespace's package: the resolution/adapter-wrapping logic lives
  # inside each namespace, not here.
  class Engine < ::Rails::Engine
    isolate_namespace Wild

    config.before_configuration do
      # Hook for Wild::Configuration finalization. Filled in during P1.
    end

    config.after_initialize do
      Wild::AdminTools.bridge_configuration!
      Wild::Introspection.bridge_configuration!
    end
  end
end
