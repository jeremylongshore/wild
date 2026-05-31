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

    # Session-telemetry knobs carried from the old wild-session-telemetry gem
    # (Role 5 PR-8). Defaults preserved verbatim.
    it "Collector defaults store to nil, retention_days 90, privacy_mode :strict, max_storage_bytes nil" do
      expect(telemetry.collector.store).to be_nil
      expect(telemetry.collector.retention_days).to eq(90)
      expect(telemetry.collector.privacy_mode).to eq(:strict)
      expect(telemetry.collector.max_storage_bytes).to be_nil
    end

    it "Pipeline defaults sequence_strategy to :ingest_order" do
      expect(telemetry.pipeline.sequence_strategy).to eq(:ingest_order)
    end

    # Transcript-pipeline knobs carried from the old wild-transcript-pipeline
    # gem (Role 5 PR-9). Defaults preserved verbatim.
    # One cohesive defaults check across the 7 carried knobs — splitting into
    # 7 examples would be vanity granularity (F3).
    it "Pipeline carries the transcript knobs with their old-gem defaults" do # rubocop:disable RSpec/MultipleExpectations
      expect(telemetry.pipeline.intent_confidence_threshold).to eq(0.5)
      expect(telemetry.pipeline.max_turn_content_length).to eq(10_000)
      expect(telemetry.pipeline.max_turns_per_transcript).to eq(1_000)
      expect(telemetry.pipeline.redaction_marker).to eq("[REDACTED]")
      expect(telemetry.pipeline.strip_absolute_paths).to be(true)
      expect(telemetry.pipeline.strip_file_contents).to be(true)
      expect(telemetry.pipeline.custom_patterns).to eq([])
    end

    it "Analysis defaults gap_threshold to 0.7" do
      expect(telemetry.analysis.gap_threshold).to eq(0.7)
    end

    # Gap-miner thresholds carried from the old wild-gap-miner gem (Role 5
    # PR-10). Defaults preserved verbatim from the gem's DEFAULTS hash.
    it "Analysis carries the gap-miner thresholds with their old-gem defaults" do # rubocop:disable RSpec/MultipleExpectations
      expect(telemetry.analysis.denial_threshold).to eq(0.2)
      expect(telemetry.analysis.failure_threshold).to eq(0.15)
      expect(telemetry.analysis.latency_p95_threshold_ms).to eq(500.0)
      expect(telemetry.analysis.utilization_min_count).to eq(5)
      expect(telemetry.analysis.coverage_min_fraction).to eq(0.3)
      expect(telemetry.analysis.pattern_min_occurrences).to eq(3)
      expect(telemetry.analysis.max_gaps_per_type).to eq(50)
      expect(telemetry.analysis.severity_weights[:denial]).to eq(1.0)
    end
  end

  describe Wild::Configuration::Hooks do
    subject(:hooks) { described_class.new }

    # Defaults preserved verbatim from the old wild-hook-ops gem's
    # Configuration so the Role 5 move is behavior-equivalent.
    it "defaults default_timeout_ms to 5_000" do
      expect(hooks.default_timeout_ms).to eq(5_000)
    end

    it "defaults max_handlers_per_hook to 20" do
      expect(hooks.max_handlers_per_hook).to eq(20)
    end

    it "defaults enable_audit_logging to true" do
      expect(hooks.enable_audit_logging).to be(true)
    end

    it "defaults max_audit_entries to 10_000" do
      expect(hooks.max_audit_entries).to eq(10_000)
    end

    it "defaults execution_mode to :sequential" do
      expect(hooks.execution_mode).to eq(:sequential)
    end

    it "defaults on_handler_error to :log_and_continue" do
      expect(hooks.on_handler_error).to eq(:log_and_continue)
    end

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

    # Audit-policy knobs carried from the old wild-permission-analyzer gem
    # (Role 5 PR-6). Defaults preserved verbatim.
    it "Permission defaults capabilities_path + grants_path to nil (engineer-supplied)" do
      expect(analyzers.permission.capabilities_path).to be_nil
      expect(analyzers.permission.grants_path).to be_nil
    end

    it "Permission defaults risk_levels to the four-tier severity map" do
      expect(analyzers.permission.risk_levels).to eq(
        "low" => 1, "medium" => 2, "high" => 3, "critical" => 4
      )
    end

    it "Permission defaults wildcard_risk_threshold to medium" do
      expect(analyzers.permission.wildcard_risk_threshold).to eq("medium")
    end

    # max_prerequisite_depth was removed (wild-0e0) — tri-color DFS made the
    # depth knob inert; dead config was cut. No default to assert.
    it "Permission does not expose a max_prerequisite_depth knob" do
      expect(analyzers.permission).not_to respond_to(:max_prerequisite_depth)
    end

    it "TestFlakes defaults classifier_corpus_path to nil (engineer-supplied)" do
      expect(analyzers.test_flakes.classifier_corpus_path).to be_nil
    end

    # Flake-detection knobs carried from the old wild-test-flake-forensics gem
    # (Role 5 PR-7). Defaults preserved verbatim.
    it "TestFlakes defaults minimum_runs to 3" do
      expect(analyzers.test_flakes.minimum_runs).to eq(3)
    end

    it "TestFlakes defaults flake_rate_threshold to 0.1" do
      expect(analyzers.test_flakes.flake_rate_threshold).to eq(0.1)
    end

    it "TestFlakes defaults max_history_entries to 10_000" do
      expect(analyzers.test_flakes.max_history_entries).to eq(10_000)
    end

    it "TestFlakes defaults severity_weights to all-1.0 four-signal map" do
      expect(analyzers.test_flakes.severity_weights).to eq(
        flake_rate: 1.0, failure_count: 1.0, trend: 1.0, confidence: 1.0
      )
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
