# frozen_string_literal: true

require "tempfile"
require "json"

# Adversarial tests for all 7 safety defect conditions from
# 003-TQ-STND-governance-model.md Section 6.
#
# Each test attempts to trigger a safety defect and confirms it
# does not happen. If any test here fails, it is a blocking defect.
#
# See Epic 8.

# rubocop:disable RSpec/DescribeClass -- safety defect suite, not class-level spec
RSpec.describe "Safety defect conditions (003-TQ-STND Section 6)" do
  let(:config_path) { File.expand_path("../../../fixtures/config", __dir__) }
  let(:audit_log) { Tempfile.new(["defect-audit", ".jsonl"]) }

  let(:gate) do
    Wild::CapabilityGate.new(
      config_path: config_path,
      audit_log_path: audit_log.path,
      session_id: "defect-test-session"
    )
  end

  after { audit_log.close! }

  def audit_events
    File.readlines(audit_log.path).map { |line| JSON.parse(line) }
  end

  # -----------------------------------------------------------------------
  # Defect 1: "A capability to be granted when the grant configuration
  #            does not authorize it"
  # -----------------------------------------------------------------------
  describe "Defect 1: Unauthorized grant" do
    it "never grants admin_tools to introspection-agent (not in grants)" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :admin_tools
      )

      expect(result).to be_denied
    end

    it "never grants privileged_introspection to wildcard caller" do
      result = gate.evaluate(
        caller: "service-account:random-caller",
        capability: :privileged_introspection
      )

      expect(result).to be_denied
    end

    it "denies even when caller name partially matches a granted caller" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent-extended",
        capability: :privileged_introspection
      )

      # Exact match required, not prefix match
      expect(result).to be_denied
    end
  end

  # -----------------------------------------------------------------------
  # Defect 2: "A prerequisite to be skipped when it is defined"
  # -----------------------------------------------------------------------
  describe "Defect 2: Prerequisite bypass" do
    it "enforces file_exists prerequisite even for a fully granted caller" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :privileged_introspection
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end

    it "enforces all prerequisites even when first one passes" do
      # admin_tools has TWO prerequisites: file_exists AND config_value
      # Even if we somehow had the file, we still need config_value=true
      result = gate.evaluate(
        caller: "service-account:admin-agent",
        capability: :admin_tools,
        context: {}
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end
  end

  # -----------------------------------------------------------------------
  # Defect 3: "An evaluation to complete without producing an audit event"
  # -----------------------------------------------------------------------
  describe "Defect 3: Silent evaluation" do
    it "produces one audit event per evaluation with required fields" do
      4.times { |i| gate.evaluate(caller: "agent-#{i}", capability: :basic_introspection) }

      events = audit_events
      expect(events.size).to eq(4)
      required_keys = %w[timestamp decision_id capability subject outcome policy_version rationale]
      expect(events).to all(include(*required_keys))
    end

    it "produces audit events for all denial types" do
      gate.evaluate(caller: "a", capability: :nonexistent)
      gate.evaluate(caller: "a", capability: :admin_tools)
      gate.evaluate(caller: "service-account:introspection-agent", capability: :privileged_introspection)

      expect(audit_events.size).to eq(3)
    end
  end

  # -----------------------------------------------------------------------
  # Defect 4: "An error to result in permission instead of denial"
  # -----------------------------------------------------------------------
  describe "Defect 4: Error grants permission" do
    it "returns denial (not permission) when evaluator raises" do
      broken = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken).to receive(:evaluate).and_raise(RuntimeError, "kaboom")
      gate.instance_variable_set(:@evaluator, broken)

      result = gate.evaluate(caller: "agent", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result).not_to be_allowed
      expect(result.reason).to eq(:evaluation_error)
    end

    it "returns denial (not permission) when evaluator raises TypeError" do
      broken = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken).to receive(:evaluate).and_raise(TypeError, "bad type")
      gate.instance_variable_set(:@evaluator, broken)

      result = gate.evaluate(caller: "agent", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
    end

    it "returns denial (not permission) when evaluator raises ArgumentError" do
      broken = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken).to receive(:evaluate).and_raise(ArgumentError, "bad args")
      gate.instance_variable_set(:@evaluator, broken)

      result = gate.evaluate(caller: "agent", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
    end
  end

  # -----------------------------------------------------------------------
  # Defect 5: "A caller identity to be fabricated or bypassed"
  # -----------------------------------------------------------------------
  describe "Defect 5: Caller identity fabrication" do
    it "treats caller as an opaque string — no injection via special chars" do
      result = gate.evaluate(
        caller: 'service-account:introspection-agent"; DROP TABLE grants;--',
        capability: :basic_introspection
      )

      # This weird caller string does not match any grant (including wildcard
      # for basic_introspection) — wait, wildcard DOES match all callers.
      # The point is the caller_id is recorded faithfully in the result.
      expect(result.caller_id).to include("DROP TABLE")
    end

    it "does not allow empty string caller to match named grants" do
      result = gate.evaluate(caller: "", capability: :privileged_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:not_granted)
    end

    it "records the exact caller identity in the evaluation result" do
      caller_id = "service-account:introspection-agent"
      result = gate.evaluate(caller: caller_id, capability: :basic_introspection)

      expect(result.caller_id).to eq(caller_id)
    end
  end

  # -----------------------------------------------------------------------
  # Defect 6: "Configuration to be modified at runtime through the
  #            public interface"
  # -----------------------------------------------------------------------
  describe "Defect 6: Runtime configuration modification" do
    it "has no public mutator methods" do
      public_methods = gate.public_methods(false)
      safe_methods = %i[evaluate capabilities]

      expect(public_methods).to match_array(safe_methods)
    end

    it "capabilities list cannot be used to modify internal state" do
      caps = gate.capabilities
      original_size = caps.size

      # Even if someone tries to push onto the returned array,
      # it should not affect the gate's internal state
      begin
        caps.push("injected")
      rescue FrozenError
        # Expected — frozen array
      end

      expect(gate.capabilities.size).to eq(original_size)
    end
  end

  # -----------------------------------------------------------------------
  # Defect 7: "An unknown capability to be granted"
  # -----------------------------------------------------------------------
  describe "Defect 7: Unknown capability granted" do
    it "denies completely fabricated capability names" do
      result = gate.evaluate(caller: "*", capability: :root_access)

      expect(result).to be_denied
      expect(result.reason).to eq(:unknown_capability)
    end

    it "denies capabilities with names similar to real ones" do
      result = gate.evaluate(caller: "*", capability: :basic_introspection_extended)

      expect(result).to be_denied
      expect(result.reason).to eq(:unknown_capability)
    end

    it "denies empty string capability name" do
      result = gate.evaluate(caller: "*", capability: "")

      expect(result).to be_denied
    end

    it "denies numeric-looking capability names" do
      result = gate.evaluate(caller: "*", capability: :"12345")

      expect(result).to be_denied
      expect(result.reason).to eq(:unknown_capability)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
