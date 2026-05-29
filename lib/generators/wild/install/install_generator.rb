# frozen_string_literal: true

require "rails/generators/base"

module Wild
  module Generators
    # rails g wild:install
    #
    # Creates:
    #   - config/initializers/wild.rb     (Wild.configure block with safe defaults)
    #   - config/wild/access_policy.yml   (Wild::Introspection policy)
    #   - config/wild/capabilities.yml    (Wild::CapabilityGate rules)
    #
    # And mounts Wild::Engine at /wild in routes.rb.
    #
    # Full implementation lands in P2 (Role 8, dx-optimizer). This skeleton
    # exists so the generator class is referenceable from day one.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs wild engine + safe defaults for access policy and capability gate."

      def warn_pending
        say_status :pending, "rails g wild:install is implemented in P2. Stub generator only.", :yellow
      end
    end
  end
end
