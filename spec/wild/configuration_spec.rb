# frozen_string_literal: true

RSpec.describe Wild::Configuration do
  subject(:config) { described_class.new }

  describe "global accessors" do
    it "exposes a writable audit_logger (defaults to nil)" do
      expect(config.audit_logger).to be_nil
      config.audit_logger = :logger
      expect(config.audit_logger).to eq(:logger)
    end

    it "exposes a writable environment (defaults to :development)" do
      expect(config.environment).to eq(:development)
      config.environment = :production
      expect(config.environment).to eq(:production)
    end
  end

  describe "namespace readers" do
    it "exposes exactly the seven namespaces declared in NAMESPACES" do
      expect(described_class::NAMESPACES).to contain_exactly(
        :introspection,
        :admin_tools,
        :capability_gate,
        :telemetry,
        :hooks,
        :analyzers,
        :skillops
      )
    end

    described_class::NAMESPACES.each do |ns|
      it "returns a typed container for #{ns} (class name == camelized namespace)" do
        container = config.public_send(ns)
        expected_class_name = ns.to_s.split("_").map(&:capitalize).join
        expect(container).not_to be_nil
        expect(container.class.name).to end_with(expected_class_name)
      end
    end
  end

  describe Wild::Configuration::Introspection do
    subject(:introspection) { described_class.new }

    it "defaults access_policy_path to nil and allowed_models to nil" do
      expect(introspection.access_policy_path).to be_nil
      expect(introspection.allowed_models).to be_nil
    end

    it "accepts mutation through the writer" do
      introspection.access_policy_path = "/etc/wild/policy.yml"
      expect(introspection.access_policy_path).to eq("/etc/wild/policy.yml")
    end
  end

  describe Wild::Configuration::AdminTools do
    subject(:admin_tools) { described_class.new }

    it "defaults adapters to :default (resolved at engine boot)" do
      expect(admin_tools.cache_adapter).to eq(:default)
      expect(admin_tools.job_adapter).to eq(:default)
      expect(admin_tools.flag_adapter).to eq(:default)
    end

    it "accepts adapter overrides" do
      admin_tools.cache_adapter = :memcached
      expect(admin_tools.cache_adapter).to eq(:memcached)
    end
  end

  describe Wild::Configuration::CapabilityGate do
    subject(:capability_gate) { described_class.new }

    it "defaults on_evaluation_error to :hard_fail per F2 mandate" do
      expect(capability_gate.on_evaluation_error).to eq(:hard_fail)
    end

    it "defaults capabilities_path to nil (engineer-supplied)" do
      expect(capability_gate.capabilities_path).to be_nil
    end
  end

  describe Wild::Configuration::Telemetry do
    subject(:telemetry) { described_class.new }

    it "exposes three sub-namespaces (collector, pipeline, analysis)" do
      expect(telemetry.collector).to be_a(Wild::Configuration::Telemetry::Collector)
      expect(telemetry.pipeline).to be_a(Wild::Configuration::Telemetry::Pipeline)
      expect(telemetry.analysis).to be_a(Wild::Configuration::Telemetry::Analysis)
    end

    it "Collector defaults enabled to true" do
      expect(telemetry.collector.enabled).to be(true)
    end

    it "Pipeline defaults sequence_strategy to :ingest_order" do
      expect(telemetry.pipeline.sequence_strategy).to eq(:ingest_order)
    end

    it "Analysis defaults gap_threshold to 0.7" do
      expect(telemetry.analysis.gap_threshold).to eq(0.7)
    end
  end

  describe Wild::Configuration::Hooks do
    subject(:hooks) { described_class.new }

    it "defaults lifecycle to :rails_engine" do
      expect(hooks.lifecycle).to eq(:rails_engine)
    end
  end

  describe Wild::Configuration::Analyzers do
    subject(:analyzers) { described_class.new }

    it "exposes two sub-namespaces (permission, test_flakes)" do
      expect(analyzers.permission).to be_a(Wild::Configuration::Analyzers::Permission)
      expect(analyzers.test_flakes).to be_a(Wild::Configuration::Analyzers::TestFlakes)
    end

    it "Permission defaults cycle_detection to :strict" do
      expect(analyzers.permission.cycle_detection).to eq(:strict)
    end

    it "TestFlakes defaults classifier_corpus_path to nil (engineer-supplied)" do
      expect(analyzers.test_flakes.classifier_corpus_path).to be_nil
    end
  end

  describe Wild::Configuration::Skillops do
    subject(:skillops) { described_class.new }

    it "defaults enabled to false per F5 (internal namespace by default)" do
      expect(skillops.enabled).to be(false)
    end
  end

  describe "Wild.configure DSL" do
    around do |example|
      original = Wild.config
      Wild.instance_variable_set(:@config, described_class.new)
      example.run
    ensure
      Wild.instance_variable_set(:@config, original)
    end

    it "yields the singleton configuration" do
      yielded = nil
      Wild.configure { |c| yielded = c }
      expect(yielded).to equal(Wild.config)
    end

    it "sets global accessors via Wild.configure" do
      Wild.configure do |c|
        c.audit_logger = :stub_logger
        c.environment = :test
      end
      expect(Wild.config.audit_logger).to eq(:stub_logger)
      expect(Wild.config.environment).to eq(:test)
    end

    it "sets per-namespace nested settings via Wild.configure" do
      Wild.configure do |c|
        c.introspection.access_policy_path = "/tmp/policy.yml"
        c.telemetry.collector.enabled = false
        c.analyzers.permission.cycle_detection = :lenient
      end
      expect(Wild.config.introspection.access_policy_path).to eq("/tmp/policy.yml")
      expect(Wild.config.telemetry.collector.enabled).to be(false)
      expect(Wild.config.analyzers.permission.cycle_detection).to eq(:lenient)
    end

    it "preserves F2 + F5 council defaults when not overridden" do
      Wild.configure { |c| c.environment = :test }
      expect(Wild.config.capability_gate.on_evaluation_error).to eq(:hard_fail)
      expect(Wild.config.skillops.enabled).to be(false)
    end
  end
end
