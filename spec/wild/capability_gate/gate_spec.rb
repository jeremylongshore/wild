# frozen_string_literal: true

require "tempfile"
require "json"

RSpec.describe Wild::CapabilityGate::Gate do
  let(:config_path) { File.expand_path("../../fixtures/config", __dir__) }

  describe ".new / Wild::CapabilityGate.new" do
    it "initializes from a config directory" do
      gate = described_class.new(config_path: config_path)

      expect(gate).to be_a(described_class)
    end

    it "is accessible via Wild::CapabilityGate.new" do
      gate = Wild::CapabilityGate.new(config_path: config_path)

      expect(gate).to be_a(described_class)
    end

    it "raises when config directory does not exist" do
      expect do
        described_class.new(config_path: "/nonexistent/config")
      end.to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError)
    end

    it "accepts optional audit_log_path" do
      log = Tempfile.new(["audit", ".jsonl"])
      gate = described_class.new(config_path: config_path, audit_log_path: log.path)

      expect(gate).to be_a(described_class)
      log.close!
    end

    it "accepts optional session_id" do
      gate = described_class.new(config_path: config_path, session_id: "sess-001")

      expect(gate).to be_a(described_class)
    end
  end

  describe "#evaluate" do
    subject(:gate) { described_class.new(config_path: config_path) }

    context "when caller is granted a standard capability" do
      it "returns allowed" do
        result = gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: :basic_introspection
        )

        expect(result).to be_allowed
        expect(result.capability_name).to eq(:basic_introspection)
        expect(result.caller_id).to eq("service-account:introspection-agent")
      end
    end

    context "when capability is unknown" do
      it "returns denied with :unknown_capability" do
        result = gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: :nonexistent
        )

        expect(result).to be_denied
        expect(result.reason).to eq(:unknown_capability)
      end
    end

    context "when caller is not granted" do
      it "returns denied with :not_granted" do
        result = gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: :admin_tools
        )

        expect(result).to be_denied
        expect(result.reason).to eq(:not_granted)
      end
    end

    context "with string capability names" do
      it "accepts strings and normalizes to symbols" do
        result = gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: "basic_introspection"
        )

        expect(result).to be_allowed
        expect(result.capability_name).to eq(:basic_introspection)
      end
    end

    context "with wildcard grants" do
      it "grants standard capabilities to any caller" do
        result = gate.evaluate(
          caller: "service-account:totally-unknown",
          capability: :basic_introspection
        )

        expect(result).to be_allowed
      end
    end

    context "with context parameter" do
      it "passes context through to prerequisite checks" do
        result = gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: :basic_introspection,
          context: { "env" => "test" }
        )

        expect(result).to be_allowed
      end
    end
  end

  describe "#evaluate fail-closed error handling" do
    it "returns denial when evaluation raises an unexpected error" do
      gate = described_class.new(config_path: config_path)

      broken_evaluator = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken_evaluator).to receive(:evaluate)
        .and_raise(RuntimeError, "unexpected failure")
      gate.instance_variable_set(:@evaluator, broken_evaluator)

      result = gate.evaluate(caller: "test", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
      expect(result.details).to include("RuntimeError")
    end

    it "preserves capability_name and caller_id in error denial" do
      gate = described_class.new(config_path: config_path)

      broken_evaluator = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken_evaluator).to receive(:evaluate).and_raise(RuntimeError)
      gate.instance_variable_set(:@evaluator, broken_evaluator)

      result = gate.evaluate(caller: "test-agent", capability: :admin_tools)

      expect(result.capability_name).to eq(:admin_tools)
      expect(result.caller_id).to eq("test-agent")
    end
  end

  describe "#capabilities" do
    subject(:gate) { described_class.new(config_path: config_path) }

    it "returns all known capabilities" do
      caps = gate.capabilities

      expect(caps).to be_an(Array)
      expect(caps.size).to eq(3)
    end

    it "returns Capability objects" do
      caps = gate.capabilities

      expect(caps.first).to be_a(Wild::CapabilityGate::Capability)
    end

    it "includes capabilities by name" do
      names = gate.capabilities.map(&:name)

      expect(names).to contain_exactly(:basic_introspection, :privileged_introspection, :admin_tools)
    end

    it "returns read-only data (capabilities are frozen)" do
      expect(gate.capabilities).to all(be_frozen)
    end
  end
end
