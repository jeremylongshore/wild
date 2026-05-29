# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-cobertura"

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
                                                                   SimpleCov::Formatter::HTMLFormatter,
                                                                   SimpleCov::Formatter::CoberturaFormatter
                                                                 ])

  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/bin/"
    add_filter "/lib/generators/"

    add_group "Introspection",      "lib/wild/introspection"
    add_group "AdminTools",         "lib/wild/admin_tools"
    add_group "CapabilityGate",     "lib/wild/capability_gate"
    add_group "Telemetry",          "lib/wild/telemetry"
    add_group "Hooks",              "lib/wild/hooks"
    add_group "Analyzers",          "lib/wild/analyzers"
    add_group "Skillops",           "lib/wild/skillops"
    add_group "Engine",             %w[lib/wild.rb lib/wild/engine.rb lib/wild/configuration.rb lib/wild/error.rb lib/wild/version.rb]

    minimum_coverage 85
    minimum_coverage_by_file 75
  end
end

require "wild"

RSpec.configure do |config|
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
