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

    it 'records the audit event with result "evaluation_error" — distinct from "denied"' do
      evaluate!
      expect(collecting_writer.events.first["result"]).to eq("evaluation_error")
    end

    it "preserves the caller + capability in the evaluation_error audit record" do
      evaluate!
      event = collecting_writer.events.first
      expect(event["caller_id"]).to eq("service-account:introspection-agent")
      expect(event["capability"]).to eq("basic_introspection")
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
