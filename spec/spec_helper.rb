# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-cobertura"

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::CoberturaFormatter
    ]
  )

  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/bin/"
    add_filter "/lib/generators/"

    add_group "Introspection",  "lib/wild/introspection"
    add_group "AdminTools",     "lib/wild/admin_tools"
    add_group "CapabilityGate", "lib/wild/capability_gate"
    add_group "Telemetry",      "lib/wild/telemetry"
    add_group "Hooks",          "lib/wild/hooks"
    add_group "Analyzers",      "lib/wild/analyzers"
    add_group "Skillops",       "lib/wild/skillops"
    add_group "Engine", %w[
      lib/wild.rb
      lib/wild/engine.rb
      lib/wild/configuration.rb
      lib/wild/error.rb
      lib/wild/version.rb
    ]

    minimum_coverage 85
    # minimum_coverage_by_file 75 is the engineer-set policy in
    # tests/TESTING.md § Thresholds. Disabled on the skeleton until Role 5
    # lands real code in P1 — enforcing 75% per-file against placeholder
    # Wild::Engine init hooks is vanity coverage per council F3.
    # Re-enable at end of P1 when Role 7 closes wild-rvv.7.1.
    # minimum_coverage_by_file 75
  end
end

require "wild"

# Wild::Introspection specs run against a live in-memory ActiveRecord schema
# (the gem inspects real Rails models). ActiveRecord is already loaded via
# Wild::Engine's `require "rails"`; we establish a throwaway sqlite connection
# and load the test schema + models once. This is global but harmless to the
# non-AR namespaces (they never touch the connection or the test models).
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
require_relative "support/wild_introspection/test_schema"
require_relative "support/wild_introspection/test_models"

require_relative "support/wild_hooks/hook_fixtures"
require_relative "support/wild_skillops/fixtures"
require_relative "support/wild_analyzers_permission/fixtures"
require_relative "support/wild_analyzers_test_flakes/fixtures"
require_relative "support/wild_telemetry_collector/event_fixtures"
require_relative "support/wild_telemetry_pipeline/fixtures"
require_relative "support/wild_telemetry_analysis/telemetry_fixtures"
require_relative "support/wild_introspection/test_config_helper"

RSpec.configure do |config|
  # Fixture modules are scoped to their own namespace's spec subtree by
  # file_path. Several modules share helper names (e.g. build_event exists in
  # both HookFixtures and the telemetry TelemetryFixtures) — a global include
  # would let the last-loaded module shadow the others. Path-scoping keeps each
  # namespace's helpers bound to its own specs.
  config.include Wild::Hooks::TestSupport::HookFixtures,
                 file_path: %r{spec/wild/hooks/}
  config.include Wild::Skillops::TestSupport::Fixtures,
                 file_path: %r{spec/wild/skillops/}
  config.include Wild::Analyzers::Permission::TestSupport::Fixtures,
                 file_path: %r{spec/wild/analyzers/permission/}
  config.include Wild::Analyzers::TestFlakes::TestSupport::Fixtures,
                 file_path: %r{spec/wild/analyzers/test_flakes/}
  config.include Wild::Telemetry::Collector::TestSupport::EventFixtures,
                 file_path: %r{spec/wild/telemetry/collector/}
  config.include Wild::Telemetry::Pipeline::TestSupport::TranscriptFixtures,
                 file_path: %r{spec/wild/telemetry/pipeline/}
  config.include Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures,
                 file_path: %r{spec/wild/telemetry/analysis/}
  config.include Wild::Introspection::TestSupport::TestConfigHelper,
                 file_path: %r{spec/wild/introspection/}

  # Introspection keeps a memoized policy-loader (Wild::Introspection.configuration)
  # + an adapter connection pool; reset both between its examples so policy and
  # connection state never leak. Scoped to introspection specs only.
  config.before(file_path: %r{spec/wild/introspection/}) do
    Wild::Introspection.reset!
    Wild::Introspection::Adapter::ConnectionManager.reset!
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/.rspec_status"

  config.disable_monkey_patching!

  config.warnings = false

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand(config.seed)

  config.before do
    Wild.reset_config! if Wild.respond_to?(:reset_config!)
  end
end
