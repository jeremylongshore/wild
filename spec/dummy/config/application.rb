# frozen_string_literal: true

require_relative "boot"

require "rails"
# Only the framework Wild::Engine actually exercises for routing (mounting
# needs ActionDispatch's routing DSL). Deliberately NOT `active_record/railtie`:
# its `active_record.initialize_database` initializer would call
# `ActiveRecord::Base.establish_connection` against spec/dummy/config/database.yml,
# replacing the in-memory sqlite connection + schema spec_helper.rb already set
# up for the introspection specs — since spec/engine/engine_spec.rb runs in the
# same `bundle exec rspec` process as the rest of the suite (see that file's
# header comment), that reconnection silently wiped every introspection
# fixture table. This is a minimal host app for CI gates (Packwerk, Brakeman)
# and the engine smoke spec, not a scaffold for feature development.
require "action_controller/railtie"

require "wild"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1

    # Wild::Engine is mounted for routing coverage only; no app/ tree of
    # our own to eager-load.
    config.eager_load = false
    config.cache_classes = true

    config.hosts.clear if config.respond_to?(:hosts)

    # Rails::Application#find_root walks up from this file looking for a
    # Gemfile and stops at the repo root (spec/dummy has none of its own) —
    # so `Rails.root` is the gem root, not spec/dummy/. That's required for
    # Packwerk (below): its Zeitwerk-derived autoload paths must fall under
    # Rails.root to be recognized. It does mean the handful of Rails::Paths
    # that are conventionally dummy-app-relative need pointing back at
    # spec/dummy/ explicitly.
    config.paths["config/routes.rb"] = "spec/dummy/config/routes.rb"
    config.paths["config/database"] = "spec/dummy/config/database.yml"
    config.paths["log"] = "spec/dummy/log/#{Rails.env}.log"
    config.paths["tmp"] = "spec/dummy/tmp"

    # Packwerk (`bundle exec packwerk check`) maps constants to files via
    # this app's Zeitwerk autoload paths (Packwerk::RailsLoadPaths). `wild`
    # doesn't use Zeitwerk itself (lib/wild.rb loads every namespace with
    # explicit `require`s), so this dummy app registers `lib` as an
    # autoload root purely so Packwerk's constant→file map exists. The five
    # engine-substrate files (root package.yml's domain; excluded from
    # per-namespace packages in packwerk.yml) are ignored here for the same
    # reason: they're plain top-level requires, not Zeitwerk-conformant
    # (lib/wild/version.rb defines the constant `VERSION`, not a class or
    # module named `Version`, which Zeitwerk's inflector would reject).
    config.autoload_paths << root.join("lib")
    Rails.autoloaders.main.ignore(
      root.join("lib/wild.rb"),
      root.join("lib/wild/version.rb"),
      root.join("lib/wild/error.rb"),
      root.join("lib/wild/configuration.rb"),
      root.join("lib/wild/engine.rb"),
      root.join("lib/generators"),
      root.join("lib/wild/schemas")
    )
  end
end
