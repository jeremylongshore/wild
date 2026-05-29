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
      it "returns a non-nil container for #{ns}" do
        expect(config.public_send(ns)).not_to be_nil
      end
    end
  end

  describe Wild::Configuration::Introspection do
    it "defaults access_policy_path to nil and allowed_models to nil" do
      expect(subject.access_policy_path).to be_nil
      expect(subject.allowed_models).to be_nil
    end

    it "accepts mutation through the writer" do
      subject.access_policy_path = "/etc/wild/policy.yml"
      expect(subject.access_policy_path).to eq("/etc/wild/policy.yml")
    end
  end

  describe Wild::Configuration::AdminTools do
    it "defaults adapters to :default (resolved at engine boot)" do
      expect(subject.cache_adapter).to eq(:default)
      expect(subject.job_adapter).to eq(:default)
      expect(subject.flag_adapter).to eq(:default)
    end

    it "accepts adapter overrides" do
      subject.cache_adapter = :memcached
      expect(subject.cache_adapter).to eq(:memcached)
    end
  end

  describe Wild::Configuration::CapabilityGate do
    it "defaults on_evaluation_error to :hard_fail per F2 mandate" do
      expect(subject.on_evaluation_error).to eq(:hard_fail)
    end

    it "defaults capabilities_path to nil (engineer-supplied)" do
      expect(subject.capabilities_path).to be_nil
    end
  end

  describe Wild::Configuration::Telemetry do
    it "exposes three sub-namespaces (collector, pipeline, analysis)" do
      expect(subject.collector).to be_a(Wild::Configuration::Telemetry::Collector)
      expect(subject.pipeline).to be_a(Wild::Configuration::Telemetry::Pipeline)
      expect(subject.analysis).to be_a(Wild::Configuration::Telemetry::Analysis)
    end

    it "Collector defaults enabled to true" do
      expect(subject.collector.enabled).to be(true)
    end

    it "Pipeline defaults sequence_strategy to :ingest_order" do
      expect(subject.pipeline.sequence_strategy).to eq(:ingest_order)
    end

    it "Analysis defaults gap_threshold to 0.7" do
      expect(subject.analysis.gap_threshold).to eq(0.7)
    end
  end

  describe Wild::Configuration::Hooks do
    it "defaults lifecycle to :rails_engine" do
      expect(subject.lifecycle).to eq(:rails_engine)
    end
  end

  describe Wild::Configuration::Analyzers do
    it "exposes two sub-namespaces (permission, test_flakes)" do
      expect(subject.permission).to be_a(Wild::Configuration::Analyzers::Permission)
      expect(subject.test_flakes).to be_a(Wild::Configuration::Analyzers::TestFlakes)
    end

    it "Permission defaults cycle_detection to :strict" do
      expect(subject.permission.cycle_detection).to eq(:strict)
    end

    it "TestFlakes defaults classifier_corpus_path to nil (engineer-supplied)" do
      expect(subject.test_flakes.classifier_corpus_path).to be_nil
    end
  end

  describe Wild::Configuration::Skillops do
    it "defaults enabled to false per F5 (internal namespace by default)" do
      expect(subject.enabled).to be(false)
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

    it "supports the canonical end-to-end mutation pattern" do
      Wild.configure do |c|
        c.audit_logger = :stub_logger
        c.environment = :test
        c.introspection.access_policy_path = "/tmp/policy.yml"
        c.capability_gate.on_evaluation_error = :hard_fail
        c.telemetry.collector.enabled = false
        c.telemetry.analysis.gap_threshold = 0.42
        c.analyzers.permission.cycle_detection = :lenient
        c.skillops.enabled = true
      end

      expect(Wild.config.audit_logger).to eq(:stub_logger)
      expect(Wild.config.environment).to eq(:test)
      expect(Wild.config.introspection.access_policy_path).to eq("/tmp/policy.yml")
      expect(Wild.config.capability_gate.on_evaluation_error).to eq(:hard_fail)
      expect(Wild.config.telemetry.collector.enabled).to be(false)
      expect(Wild.config.telemetry.analysis.gap_threshold).to eq(0.42)
      expect(Wild.config.analyzers.permission.cycle_detection).to eq(:lenient)
      expect(Wild.config.skillops.enabled).to be(true)
    end
  end
end
