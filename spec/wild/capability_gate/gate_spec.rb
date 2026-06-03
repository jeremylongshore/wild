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

    # Armstrong F2 fast-follow contract (wild-wxk). The invariant being pinned:
    # Evaluator#evaluate never raises (its own rescue emits the evaluation_error
    # event + denies), so today the Gate's outer rescue is unreachable. That
    # invariant is UNGUARDED — if a future refactor removes the Evaluator's
    # rescue, the Gate's outer rescue becomes the backstop, and it is audit-blind
    # BY CONSTRUCTION (the Gate holds no audit writer; emission lives in the
    # Evaluator). The two examples above already pin that the backstop fails
    # closed; the example below pins the displaced-hole's defining property —
    # when the Gate rescue fires, NO audit event is written, so a missing event
    # is the signal that the Evaluator's contract was violated.
    #
    # NOTE on mechanism: the finding originally proposed `allow_any_instance_of`,
    # but Evaluator#initialize calls `freeze`, and RSpec cannot install a
    # partial-double proxy on a frozen instance (the real method runs instead).
    # Swapping @evaluator for a verifying instance_double is the working
    # equivalent and is what these examples use.
    it "writes NO audit event when the Gate-level rescue fires (audit-blind by construction)" do
      require "tempfile"
      log = Tempfile.new(["gate-rescue", ".jsonl"])
      gate = described_class.new(config_path: config_path, audit_log_path: log.path)

      broken_evaluator = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken_evaluator).to receive(:evaluate).and_raise(RuntimeError, "contract violated")
      gate.instance_variable_set(:@evaluator, broken_evaluator)

      result = gate.evaluate(caller: "svc:agent", capability: :basic_introspection)

      expect(result.reason).to eq(:evaluation_error)
      expect(File.read(log.path)).to be_empty # the displaced F2 hole: emission was bypassed
    ensure
      log.close!
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
