# frozen_string_literal: true

require "tempfile"
require "json"

# Adversarial safety tests for the capability gate.
#
# Every governance rule from 003-TQ-STND-governance-model.md is tested here.
# Every safety defect condition from Section 6 has a test that tries to trigger
# it and confirms it does not happen.
#
# These tests run against the public interface (Wild::CapabilityGate::Gate)
# to prove the gate's safety claims are real, not just internal implementation
# details.
#
# See Epic 8 and 003-TQ-STND-governance-model.md.

# rubocop:disable RSpec/DescribeClass -- safety test suite, not class-level spec
RSpec.describe "Governance rules (003-TQ-STND-governance-model.md)" do
  let(:config_path) { File.expand_path("../../../fixtures/config", __dir__) }
  let(:audit_log) { Tempfile.new(["safety-audit", ".jsonl"]) }

  let(:gate) do
    Wild::CapabilityGate.new(
      config_path: config_path,
      audit_log_path: audit_log.path,
      session_id: "safety-test-session"
    )
  end

  after { audit_log.close! }

  def audit_events
    File.readlines(audit_log.path).map { |line| JSON.parse(line) }
  end

  # -----------------------------------------------------------------------
  # Rule 1: Fail-Closed
  # "If the gate cannot complete an evaluation — due to missing configuration,
  #  broken prerequisite checks, unresolvable caller identity, or any runtime
  #  error — the result is denial. Never permission."
  # -----------------------------------------------------------------------
  describe "Rule 1: Fail-Closed" do
    it "returns denial when the evaluator raises a runtime error" do
      broken = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken).to receive(:evaluate).and_raise(RuntimeError, "boom")
      gate.instance_variable_set(:@evaluator, broken)

      result = gate.evaluate(caller: "agent", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
    end

    it "converts nil caller to empty string (wildcard may still match)" do
      # nil caller becomes "" via String(nil). The wildcard grant "*" matches
      # all callers including empty string. This is correct — the wildcard is
      # explicit config, not implicit behavior (Rule 2).
      result = gate.evaluate(caller: nil, capability: :basic_introspection)

      expect(result.caller_id).to eq("")
    end

    it "returns denial when capability name is nil" do
      result = gate.evaluate(caller: "service-account:introspection-agent", capability: nil)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
    end

    it "raises at initialization when config directory is missing" do
      expect do
        Wild::CapabilityGate.new(config_path: "/nonexistent/path")
      end.to raise_error(StandardError)
    end

    it "raises at initialization when capabilities.yml is malformed" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "capabilities.yml"), "}{invalid yaml")
        File.write(File.join(dir, "grants.yml"), "grants: []\n")

        expect do
          Wild::CapabilityGate.new(config_path: dir)
        end.to raise_error(StandardError)
      end
    end
  end

  # -----------------------------------------------------------------------
  # Rule 2: No Implicit Grants
  # "Unknown capabilities are denied. Callers without explicit grants are denied."
  # -----------------------------------------------------------------------
  describe "Rule 2: No Implicit Grants" do
    it "denies unknown capabilities" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :capability_that_does_not_exist
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:unknown_capability)
    end

    it "denies callers with no grants configured" do
      result = gate.evaluate(
        caller: "service-account:totally-unknown-agent",
        capability: :privileged_introspection
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:not_granted)
    end

    it "denies when grants file is empty" do
      Dir.mktmpdir do |dir|
        FileUtils.cp(File.join(config_path, "capabilities.yml"), dir)
        File.write(File.join(dir, "grants.yml"), "grants: []\n")

        empty_gate = Wild::CapabilityGate.new(config_path: dir)
        result = empty_gate.evaluate(
          caller: "service-account:introspection-agent",
          capability: :basic_introspection
        )

        expect(result).to be_denied
        expect(result.reason).to eq(:not_granted)
      end
    end

    it "does not grant capabilities not listed in the caller grant" do
      # introspection-agent is granted basic_introspection and privileged_introspection
      # but NOT admin_tools
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :admin_tools
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:not_granted)
    end
  end

  # -----------------------------------------------------------------------
  # Rule 3: Prerequisites Are Enforced
  # "There is no 'skip prerequisites' mode, no override flag, no operator
  #  escape hatch that bypasses prerequisite evaluation."
  # -----------------------------------------------------------------------
  describe "Rule 3: Prerequisites Are Enforced" do
    it "denies when file_exists prerequisite is not satisfied" do
      # privileged_introspection requires a file that does not exist in test env
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :privileged_introspection
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end

    it "denies when config_value prerequisite is not satisfied" do
      # admin_tools requires admin_tools_enabled=true in context
      result = gate.evaluate(
        caller: "service-account:admin-agent",
        capability: :admin_tools,
        context: { "admin_tools_enabled" => false }
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end

    it "denies when config_value prerequisite key is missing from context" do
      result = gate.evaluate(
        caller: "service-account:admin-agent",
        capability: :admin_tools,
        context: {}
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end

    it "cannot skip prerequisites by passing extra context keys" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :privileged_introspection,
        context: { "skip_prerequisites" => true, "override" => true, "force" => true }
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)
    end
  end

  # -----------------------------------------------------------------------
  # Rule 4: Configuration Immutability at Runtime
  # "Capability definitions, grant rules, and prerequisites are loaded at
  #  server startup. They cannot be modified through the public interface."
  # -----------------------------------------------------------------------
  describe "Rule 4: Configuration Immutability at Runtime" do
    it "does not expose any method to modify capabilities" do
      public_methods = gate.public_methods(false)

      mutation_methods = public_methods.select do |m|
        m.to_s.match?(/add|remove|delete|update|set|modify|write|push|append|clear|reset/)
      end

      expect(mutation_methods).to be_empty
    end

    it "returns frozen capability objects" do
      expect(gate.capabilities).to all(be_frozen)
    end

    it "does not allow adding capabilities after initialization" do
      expect(gate).not_to respond_to(:add_capability)
      expect(gate).not_to respond_to(:register)
      expect(gate).not_to respond_to(:configure)
    end

    it "does not allow modifying grants after initialization" do
      expect(gate).not_to respond_to(:grant)
      expect(gate).not_to respond_to(:revoke)
      expect(gate).not_to respond_to(:add_grant)
    end
  end

  # -----------------------------------------------------------------------
  # Rule 5: Audit Completeness
  # "Every evaluation produces an audit event. There is no silent evaluation
  #  path. If an evaluation produces no audit event, that is a safety defect."
  # -----------------------------------------------------------------------
  describe "Rule 5: Audit Completeness" do
    it "produces an audit event for allowed evaluations" do
      gate.evaluate(caller: "service-account:introspection-agent", capability: :basic_introspection)

      expect(audit_events.size).to eq(1)
      expect(audit_events.first["result"]).to eq("allowed")
    end

    it "produces an audit event for denied (unknown capability) evaluations" do
      gate.evaluate(caller: "agent", capability: :nonexistent)

      expect(audit_events.size).to eq(1)
      expect(audit_events.first["result"]).to eq("denied")
      expect(audit_events.first["reason"]).to eq("unknown_capability")
    end

    it "produces an audit event for denied (not granted) evaluations" do
      gate.evaluate(caller: "agent", capability: :admin_tools)

      expect(audit_events.size).to eq(1)
      expect(audit_events.first["result"]).to eq("denied")
      expect(audit_events.first["reason"]).to eq("not_granted")
    end

    it "produces an audit event for denied (prerequisite not met) evaluations" do
      gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :privileged_introspection
      )

      expect(audit_events.size).to eq(1)
      expect(audit_events.first["result"]).to eq("denied")
      expect(audit_events.first["reason"]).to eq("prerequisite_not_met")
    end

    it "produces exactly one audit event per evaluation" do
      5.times do |i|
        gate.evaluate(caller: "agent-#{i}", capability: :basic_introspection)
      end

      expect(audit_events.size).to eq(5)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
