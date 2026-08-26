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
    # Evaluator#evaluate never raises for a genuine runtime/policy failure (its
    # own rescue emits the evaluation_error event + denies), so this example
    # exercises the Gate's outer StandardError rescue as the backstop for a
    # future contract violation (a stubbed RuntimeError from the evaluator),
    # not the "unreachable" backstop a prior version of this comment claimed.
    #
    # f-l08-3 correction: the Gate's outer rescue is NOT unreachable today: it
    # WAS the only thing catching the AuditSchemaError that Evaluator#evaluate
    # deliberately re-raises (see the `rescue AuditSchemaError, ConfigurationError;
    # raise` clause now ordered above it in gate.rb#evaluate), silently
    # demoting a "surface loudly" developer-bug signal into an audit-blind
    # :evaluation_error denial. See the "raises AuditSchemaError instead of
    # swallowing it" example below for that fixed path.
    #
    # This example's invariant (a genuine unexpected raise from the evaluator)
    # is UNGUARDED: if a future refactor removes the Evaluator's rescue for
    # that case, the Gate's outer rescue becomes the backstop, and it is
    # audit-blind BY CONSTRUCTION (the Gate holds no audit writer; emission
    # lives in the Evaluator). The two examples above already pin that the
    # backstop fails closed; the example below pins the displaced-hole's
    # defining property: when the Gate rescue fires, NO audit event is
    # written, so a missing event is the signal that the Evaluator's contract
    # was violated.
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

    # f-l08-3: proves the fix: Gate#evaluate now re-raises AuditSchemaError
    # from the real (non-stubbed) Evaluator instead of swallowing it into an
    # audit-blind :evaluation_error denial. Uses the same non-conforming-event
    # injection technique as audit_liveness_spec.rb's toggle examples.
    it "raises AuditSchemaError instead of swallowing it into a denial" do
      Wild.configure { |c| c.capability_gate.validate_audit_events = true }
      bad_event = instance_double(Wild::CapabilityGate::Audit::Event, to_h: { "outcome" => "maybe" })
      allow(Wild::CapabilityGate::Audit::Event).to receive(:from_evaluation).and_return(bad_event)
      log = Tempfile.new(["gate-schema", ".jsonl"])
      gate = described_class.new(config_path: config_path, audit_log_path: log.path)

      expect { gate.evaluate(caller: "svc:agent", capability: :basic_introspection) }
        .to raise_error(Wild::CapabilityGate::AuditSchemaError)
      expect(File.read(log.path)).to be_empty
    ensure
      log.close!
    end
  end

  describe "#evaluate hostile context handling (f-l08-1)" do
    # A caller-supplied non-Hash context used to raise TypeError inside
    # Audit::Event#initialize's `Hash(context)`, get swallowed by the
    # evaluator's StandardError rescue, and (with the default nil
    # audit_logger) leave the ALLOW result with zero audit lines AND zero log
    # lines. Audit::Event.coerce_context now coerces defensively before Event
    # construction.
    #
    # f-l08 addendum item 8: the original matrix had a dead ["nil", nil] row —
    # `Hash(nil)` succeeds (returns {}) so it never exercises the placeholder
    # path this describe block is about — and a wrong assumption that a
    # pairs-shaped Array converts. Verified: `Kernel#Hash` raises TypeError for
    # EVERY non-empty Array, pairs-shaped or not (`Hash([["a",1]])` raises
    # exactly like `Hash(%w[x y])` does — Array implements neither #to_hash nor
    # does Hash() fall back to #to_h). The "a pairs-shaped Array" row below
    # replaces the dead one and proves that case degrades safely too, the same
    # as any other non-empty Array.
    [
      ["a String", "not-a-hash"],
      ["a non-pair Array", %w[x y]],
      ["a pairs-shaped Array", [%w[a 1], %w[b 2]]],
      ["an object whose #to_hash raises", Class.new { def to_hash = raise("boom") }.new]
    ].each do |label, hostile_context|
      # f-l08 addendum item 14: pin the invariant — one audit line, whose
      # extra.context is exactly Audit::Event.coerce_context(hostile_context)
      # — instead of only the weaker "hostile input still returns ALLOW".
      it "writes exactly one audit line per evaluate for #{label}, with the coerced context recorded" do
        log = Tempfile.new(["gate-context", ".jsonl"])
        gate = described_class.new(config_path: config_path, audit_log_path: log.path)

        result = gate.evaluate(
          caller: "svc:a", capability: :basic_introspection, context: hostile_context
        )

        lines = File.readlines(log.path)
        expect(result).to be_allowed
        expect(lines.size).to eq(1)
        expected_context = JSON.parse(JSON.generate(Wild::CapabilityGate::Audit::Event.coerce_context(hostile_context)))
        expect(JSON.parse(lines.first).dig("extra", "context")).to eq(expected_context)
      ensure
        log.close!
      end
    end

    it "writes one line per call across repeated hostile-context evaluations" do
      log = Tempfile.new(["gate-context-multi", ".jsonl"])
      gate = described_class.new(config_path: config_path, audit_log_path: log.path)

      first = gate.evaluate(caller: "svc:a", capability: :basic_introspection)
      second = gate.evaluate(caller: "svc:a", capability: :basic_introspection, context: "not-a-hash")

      expect(first).to be_allowed
      expect(second).to be_allowed
      expect(File.readlines(log.path).size).to eq(2)
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
