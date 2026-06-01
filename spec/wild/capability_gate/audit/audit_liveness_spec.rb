# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

require "tempfile"

# F2 audit-liveness (council rev2, Armstrong's most-leveraged finding).
#
# The property under test: when evaluation ITSELF raises — not a policy denial,
# but the gate machinery breaking — the gate must (1) fail closed (deny) AND
# (2) leave an audit trail recording `evaluation_error`. A broken gate must
# never produce a silent denial, and an audit-pipeline outage must never be
# doubly silent. This spec deliberately corrupts the evaluation path and asserts
# the property holds.
#
# Owns: wild-rvv.4.1.
RSpec.describe "Wild::CapabilityGate F2 audit liveness" do
  let(:fixtures_dir) { File.expand_path("../../../fixtures", __dir__) }
  let(:capabilities_path) { File.join(fixtures_dir, "valid_capabilities.yml") }
  let(:grants_path) { File.join(fixtures_dir, "valid_grants.yml") }

  # An in-memory writer that records every event it is handed.
  let(:collecting_writer) do
    Class.new do
      attr_reader :events

      def initialize
        @events = []
      end

      def write(event)
        @events << event.to_h
        nil
      end
    end.new
  end

  describe "when the decision logic raises mid-evaluation" do
    # A registry that blows up on the membership check — stands in for any gate
    # machinery failure (corrupted grant, registry bug) the fail-closed
    # prerequisite checkers don't already absorb. `find` stays safe so the
    # audit Event can still resolve a risk_level while recording the error.
    let(:exploding_registry) do
      reg = Object.new
      def reg.known?(_capability) = raise("simulated registry corruption")
      def reg.find(_capability) = nil
      reg
    end

    let(:evaluator) do
      Wild::CapabilityGate::Evaluator.new(
        registry: exploding_registry,
        grants: [],
        audit_writer: collecting_writer,
        session_id: "liveness-session"
      )
    end

    def evaluate!
      evaluator.evaluate(
        caller_id: "service-account:introspection-agent",
        capability_name: :basic_introspection
      )
    end

    it "fails closed — returns a denial, never raises" do
      expect(evaluate!).to be_denied
    end

    it "denies with reason :evaluation_error (not a generic policy denial)" do
      expect(evaluate!.reason).to eq(:evaluation_error)
    end

    it "emits exactly one audit event for the failed evaluation" do
      evaluate!
      expect(collecting_writer.events.size).to eq(1)
    end

    it 'records the audit event with outcome "evaluation_error" — distinct from "deny"' do
      evaluate!
      expect(collecting_writer.events.first["outcome"]).to eq("evaluation_error")
    end

    it "preserves the subject + capability in the evaluation_error audit record" do
      evaluate!
      event = collecting_writer.events.first
      expect(event["subject"]).to eq("service-account:introspection-agent")
      expect(event["capability"]).to eq("basic_introspection")
    end

    # Fowler F2 gate (wild-rvv.4.1.1): the examples above prove the error event
    # is emitted — exactly once, with the right payload. They do NOT prove
    # ORDERING: that the emit COMPLETES before the denial escapes `evaluate`. A
    # refactor that returned the denial before emitting (or moved the emit into
    # a path that runs after the value is handed back) would keep every
    # count/payload example green while silently reopening the F2 hole — the
    # gate would deny without an audit trail having been written first. These
    # examples pin the sequence: emit-then-return, with the terminal event.
    #
    # NOTE the bead's original "rescue → emit → re-RAISE" framing predates the
    # shipped fail-closed contract: `evaluate` never raises, it denies. The
    # invariant under test is therefore "emit before the terminal RETURN", which
    # is the same audit-completeness guarantee Fowler's note demanded. The
    # never-consumed `on_evaluation_error` knob + unraised `EvaluationError`
    # class are tracked for decide-or-cut under wild-28y.
    describe "audit-emission ordering (emit completes before the denial is returned)" do
      # SCOPE OF THE GUARANTEE (Armstrong F2 gate): this proves the audit write
      # *call completes* before `evaluate` returns, under a SYNCHRONOUS writer —
      # the call stack enforces it. It does NOT prove durability for an async
      # writer: the day `write` enqueues a job / hands to a thread and returns
      # immediately, this stays green while the audit is merely *scheduled*, not
      # landed. "write returned" ≠ "write durable". If the writer ever becomes
      # async, a separate durability invariant is required (tracked: wild-28y).
      let(:sequence) { [] }

      # A writer that records, at write time, the order it was called in and the
      # result it carried. Closes over `sequence` so the test can interleave its
      # own "returned" marker and assert the relative order.
      let(:ordering_writer) do
        seq = sequence
        writer = Object.new
        writer.define_singleton_method(:write) do |event|
          seq << [:audit_emitted, event.to_h["outcome"]]
          nil
        end
        writer
      end

      let(:ordering_evaluator) do
        Wild::CapabilityGate::Evaluator.new(
          registry: exploding_registry,
          grants: [],
          audit_writer: ordering_writer,
          session_id: "ordering-session"
        )
      end

      it "writes the audit event BEFORE evaluate returns the denial (not after)" do
        result = ordering_evaluator.evaluate(
          caller_id: "service-account:introspection-agent",
          capability_name: :basic_introspection
        )
        sequence << [:result_returned, result.reason]

        expect(sequence).to eq(
          [
            [:audit_emitted, "evaluation_error"],
            [:result_returned, :evaluation_error] # rubocop:disable Style/SymbolArray -- parallel tuple with the line above
          ]
        )
      end

      it "emits the TERMINAL evaluation_error event (deny built before emit), exactly once" do
        ordering_evaluator.evaluate(
          caller_id: "service-account:introspection-agent",
          capability_name: :basic_introspection
        )
        emitted = sequence.select { |entry| entry.first == :audit_emitted }
        # Exactly one emit, and it carries the terminal evaluation_error result —
        # proving deny_evaluation_error ran before emit, and that no stale
        # pre-error event leaked through ahead of it.
        expect(emitted).to eq([[:audit_emitted, "evaluation_error"]])
      end
    end
  end

  describe "when caller_id coercion itself raises inside the rescue (Armstrong F2 gate)" do
    # The subtle F2 hole: a hostile caller_id whose #to_s raises blows up the
    # FIRST coercion in `evaluate`, the rescue fires, and then
    # deny_evaluation_error re-coerces the SAME hostile object — raising a second
    # time, this time INSIDE the rescue handler, so `evaluate` propagates an
    # exception with NO audit written. That is a silent non-answer: the exact
    # failure F2 exists to kill, reachable by one malformed input. The gate must
    # still fail closed, still audit, and never raise. (wild-rvv.4.1.1.)
    let(:benign_registry) do
      reg = Object.new
      # known? is reached only after coercion; with a hostile caller_id the
      # coercion raises first, so these stay safe. find/known? kept harmless so
      # the audit Event can still build under a placeholder identity.
      def reg.known?(_capability) = true
      def reg.find(_capability) = nil
      reg
    end

    let(:hostile_caller_id) do
      obj = Object.new
      def obj.to_s = raise("hostile to_s")
      obj
    end

    let(:evaluator) do
      Wild::CapabilityGate::Evaluator.new(
        registry: benign_registry,
        grants: [],
        audit_writer: collecting_writer,
        session_id: "hostile-caller-session"
      )
    end

    def evaluate!
      evaluator.evaluate(caller_id: hostile_caller_id, capability_name: :basic_introspection)
    end

    it "fails closed — returns a denial, never raises" do
      expect { evaluate! }.not_to raise_error
      expect(evaluate!).to be_denied
    end

    it "denies with reason :evaluation_error" do
      expect(evaluate!.reason).to eq(:evaluation_error)
    end

    it "still emits exactly one audit event despite the uncoercible caller_id" do
      evaluate!
      expect(collecting_writer.events.size).to eq(1)
    end

    it "audits under a stable placeholder caller identity (not silent, not crashing)" do
      evaluate!
      event = collecting_writer.events.first
      expect(event["outcome"]).to eq("evaluation_error")
      expect(event["subject"]).to eq("<uncoercible-caller-id>")
    end
  end

  describe "when the audit writer itself fails" do
    # F2: audit-pipeline failure must not be doubly silent — it is logged to
    # Wild.config.audit_logger.error — and it must not break the gate.
    let(:exploding_writer) do
      Class.new do
        def write(_event)
          raise IOError, "audit disk full"
        end
      end.new
    end

    let(:logger) { instance_spy(Logger) }

    let(:evaluator_with_bad_writer) do
      Wild::CapabilityGate::Evaluator.from_files(
        capabilities_path: capabilities_path,
        grants_path: grants_path,
        audit_writer: exploding_writer
      )
    end

    before { Wild.configure { |c| c.audit_logger = logger } }

    def evaluate!
      evaluator_with_bad_writer.evaluate(
        caller_id: "service-account:introspection-agent",
        capability_name: :basic_introspection
      )
    end

    it "does not raise out of the gate when audit write fails" do
      expect { evaluate! }.not_to raise_error
    end

    it "still returns the computed result (allow) despite the audit outage" do
      expect(evaluate!).to be_allowed
    end

    it "logs the audit-emission failure to Wild.config.audit_logger (not doubly silent)" do
      evaluate!
      expect(logger).to have_received(:error).with(/audit emission failed: IOError/)
    end
  end

  describe "when BOTH the audit writer AND the logger are broken (terminal silent path)" do
    # The one genuinely-terminal silent path, by design. It requires two
    # simultaneous failures — writer raises on write, logger raises on error.
    # The contract: the gate STILL does not raise and STILL returns its
    # computed result. This pins Armstrong's F2 terminal-silence boundary so a
    # refactor can't silently widen it.
    let(:exploding_writer) do
      Class.new do
        def write(_event) = raise(IOError, "audit disk full")
      end.new
    end

    let(:exploding_logger) do
      Class.new do
        def error(_msg) = raise(StandardError, "logger backend down")
      end.new
    end

    let(:evaluator) do
      Wild::CapabilityGate::Evaluator.from_files(
        capabilities_path: capabilities_path,
        grants_path: grants_path,
        audit_writer: exploding_writer
      )
    end

    before { Wild.configure { |c| c.audit_logger = exploding_logger } }

    it "does not raise even when the logger itself is broken" do
      expect do
        evaluator.evaluate(
          caller_id: "service-account:introspection-agent",
          capability_name: :basic_introspection
        )
      end.not_to raise_error
    end

    it "still returns the computed result when writer+logger both fail" do
      result = evaluator.evaluate(
        caller_id: "service-account:introspection-agent",
        capability_name: :basic_introspection
      )
      expect(result).to be_allowed
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
