# frozen_string_literal: true

# `spec/dummy/` boots a real (minimal) Rails app that mounts Wild::Engine —
# see spec/dummy/config/application.rb for why Rails.root ends up being the
# gem root rather than spec/dummy/ itself. Booting it here, inside a single
# spec file guarded by a load flag, keeps the one-time Rails.application
# initialization out of the rest of the suite (spec_helper.rb never
# requires it) while still running under the same `bundle exec rspec`
# process — `--require spec_helper` in .rspec applies globally, so this file
# is loaded like any other; it just does one extra thing on top.
require "spec_helper"
require_relative "../dummy/config/environment" unless defined?(Dummy::Application)

# spec/engine/ (not spec/wild/engine/) matches Rakefile's `rake test:engine`
# task pattern (`spec/engine/**/*_spec.rb`), which predates this file.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Wild::Engine do
  it "is a Rails::Engine" do
    expect(described_class.superclass).to eq(Rails::Engine)
  end

  it "isolates its namespace to Wild" do
    expect(described_class.railtie_namespace).to eq(Wild)
    expect(described_class.isolated?).to be(true)
  end

  it "is mounted at /wild in the dummy app's routes" do
    mounted_engines = Rails.application.routes.routes.map(&:app).map do |app|
      app.respond_to?(:app) ? app.app : app
    end

    expect(mounted_engines).to include(described_class)
  end

  it "names the mount point /wild" do
    route = Rails.application.routes.routes.find { |r| r.name == "wild" }

    expect(route).not_to be_nil
    expect(route.path.spec.to_s).to start_with("/wild")
  end

  describe "Wild.config namespace accessors" do
    subject(:config) { Wild.config }

    it "exposes the five single-leaf namespaces" do
      expect(config.introspection).to be_a(Wild::Configuration::Introspection)
      expect(config.admin_tools).to be_a(Wild::Configuration::AdminTools)
      expect(config.capability_gate).to be_a(Wild::Configuration::CapabilityGate)
      expect(config.hooks).to be_a(Wild::Configuration::Hooks)
      expect(config.skillops).to be_a(Wild::Configuration::Skillops)
    end

    it "exposes the three telemetry sub-namespaces" do
      expect(config.telemetry.collector).to be_a(Wild::Configuration::Telemetry::Collector)
      expect(config.telemetry.pipeline).to be_a(Wild::Configuration::Telemetry::Pipeline)
      expect(config.telemetry.analysis).to be_a(Wild::Configuration::Telemetry::Analysis)
    end

    it "exposes the two analyzers sub-namespaces" do
      expect(config.analyzers.permission).to be_a(Wild::Configuration::Analyzers::Permission)
      expect(config.analyzers.test_flakes).to be_a(Wild::Configuration::Analyzers::TestFlakes)
    end
  end

  # f-l10-3, f-x1-1, f-l09-2: config.after_initialize was comment-only, so
  # Wild.config.admin_tools/introspection were read by nothing and the
  # :default adapter sentinels never resolved. These specs exercise the two
  # bridge_configuration! entry points directly (rather than re-booting
  # Rails, which only runs after_initialize once) to prove the bridging
  # behavior itself, on top of the dummy app boot above already proving the
  # hook runs without raising at real boot time.
  describe "central-to-namespace configuration bridging" do
    let(:fixtures_path) { File.expand_path("../support/wild_introspection/fixtures", __dir__) }
    let(:access_policy_path) { File.join(fixtures_path, "access_policy.yml") }
    let(:blocked_resources_path) { File.join(fixtures_path, "blocked_resources.yml") }

    after do
      Wild::Introspection.reset!
      Wild::AdminTools.reset_configuration!
      Wild.configure do |config|
        config.admin_tools.job_adapter = Wild::AdminTools::Executor::Adapters::JobAdapter.new
        config.admin_tools.flag_adapter = Wild::AdminTools::Executor::Adapters::FlagAdapter.new
      end
      Wild::AdminTools.bridge_configuration!
    end

    describe "Wild::AdminTools.bridge_configuration! (f-l10-3, f-x1-1)" do
      it "resolves the :default cache_adapter sentinel to RailsCacheAdapter when Rails.cache is available" do
        Wild.configure do |config|
          config.admin_tools.job_adapter = Wild::AdminTools::Executor::Adapters::JobAdapter.new
          config.admin_tools.flag_adapter = Wild::AdminTools::Executor::Adapters::FlagAdapter.new
        end
        Wild::AdminTools.reset_configuration!

        Wild::AdminTools.bridge_configuration!

        expect(Wild::AdminTools.configuration.cache_adapter).to be_a(
          Wild::AdminTools::Executor::Adapters::RailsCacheAdapter
        )
      end

      it "raises Wild::ConfigurationError naming the setting when a :default adapter has no backend" do
        # Wild.config.admin_tools is fresh here (:default for all three
        # sentinels): spec_helper.rb's global `before { Wild.reset_config! }`
        # runs ahead of every example. Sidekiq isn't in this gem's
        # dependency graph (only Rails.cache always resolves), so
        # job_adapter is the first unresolvable setting.
        Wild::AdminTools.reset_configuration!

        expect { Wild::AdminTools.bridge_configuration! }.to raise_error(
          Wild::ConfigurationError, /job_adapter/
        )
      end

      it "copies an explicitly-configured adapter through unchanged" do
        custom_job_adapter = Wild::AdminTools::Executor::Adapters::JobAdapter.new
        Wild.configure do |config|
          config.admin_tools.job_adapter = custom_job_adapter
          config.admin_tools.flag_adapter = Wild::AdminTools::Executor::Adapters::FlagAdapter.new
        end
        Wild::AdminTools.reset_configuration!

        Wild::AdminTools.bridge_configuration!

        expect(Wild::AdminTools.configuration.job_adapter).to equal(custom_job_adapter)
      end
    end

    describe "Wild::Introspection.bridge_configuration! (f-l09-2)" do
      it "is a no-op when the central introspection config was never set" do
        Wild::Introspection.reset!

        expect { Wild::Introspection.bridge_configuration! }.not_to raise_error
        expect(Wild::Introspection.configuration.access_policy_path).to be_nil
      end

      it "pushes access_policy_path/blocked_resources_path into the runtime policy loader and loads it" do
        Wild.configure do |config|
          config.introspection.access_policy_path = access_policy_path
          config.introspection.blocked_resources_path = blocked_resources_path
        end
        Wild::Introspection.reset!

        Wild::Introspection.bridge_configuration!

        expect(Wild::Introspection.configuration.access_policy_path).to eq(access_policy_path)
        expect(Wild::Introspection.configuration.blocked_resources_path).to eq(blocked_resources_path)
        # model_allowed? is what every introspection tool call gates on; a
        # never-synced runtime loader (the pre-fix bug) means this is always
        # false and every call raises ModelNotAllowedError regardless of
        # the README-documented Wild.configure block.
        expect(Wild::Introspection.configuration.model_allowed?("User")).to be(true)
      end

      it "raises Wild::Introspection::ConfigError when access_policy_path is set but blocked_resources_path is not" do
        Wild.configure do |config|
          config.introspection.access_policy_path = access_policy_path
        end
        Wild::Introspection.reset!

        expect { Wild::Introspection.bridge_configuration! }.to raise_error(
          Wild::Introspection::ConfigError, /blocked_resources_path/
        )
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
