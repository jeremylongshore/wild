# frozen_string_literal: true

require "rails/engine"

module Wild
  # Wild::Engine — the Rails engine entry point. `isolate_namespace Wild`
  # confines all routes, helpers, and ActiveRecord classes to the `Wild::`
  # namespace.
  #
  # Mounted by the install generator in routes.rb:
  #
  #   mount Wild::Engine, at: "/wild"
  #
  # Final initializer order and per-namespace boot hooks are designed by
  # Role 4 in P1. This skeleton mounts cleanly so the engine is loadable
  # from the install generator's earliest dummy-app integration test.
  class Engine < ::Rails::Engine
    isolate_namespace Wild

    config.before_configuration do
      # Hook for Wild::Configuration finalization. Filled in during P1.
    end

    config.after_initialize do
      # Hook for namespace-level wire-up (autoload triggers, hooks
      # registration, etc). Filled in during P1.
    end
  end
end
