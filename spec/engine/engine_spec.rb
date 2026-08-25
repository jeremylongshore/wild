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
end
# rubocop:enable RSpec/SpecFilePathFormat
