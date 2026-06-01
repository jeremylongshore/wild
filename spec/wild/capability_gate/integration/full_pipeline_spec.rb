# frozen_string_literal: true

require "tempfile"
require "json"

# Integration test: exercises the full evaluation pipeline from the public
# interface (Wild::CapabilityGate.new) through to audit log output.
#
# This verifies that all components (registry, evaluator, prerequisites,
# audit writer) work together correctly through the Gate facade.
#
# See Epic 7, task 2gvy.
# rubocop:disable RSpec/DescribeClass -- integration test, not a class-level spec
RSpec.describe "Full pipeline integration" do
  let(:config_path) { File.expand_path("../../../fixtures/config", __dir__) }
  let(:audit_log) { Tempfile.new(["audit-integration", ".jsonl"]) }

  let(:gate) do
    Wild::CapabilityGate.new(
      config_path: config_path,
      audit_log_path: audit_log.path,
      session_id: "integration-test-session"
    )
  end

  after { audit_log.close! }

  def audit_events
    File.readlines(audit_log.path).map { |line| JSON.parse(line) }
  end

  describe "allowed evaluation produces correct audit event" do
    # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength -- integration test validates full pipeline
    it "grants capability and logs the decision" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :basic_introspection
      )

      expect(result).to be_allowed
      expect(result.capability_name).to eq(:basic_introspection)
      expect(result.caller_id).to eq("service-account:introspection-agent")

      events = audit_events
      expect(events.size).to eq(1)

      event = events.first
      expect(event["outcome"]).to eq("allow")
      expect(event["subject"]).to eq("service-account:introspection-agent")
      expect(event["capability"]).to eq("basic_introspection")
      expect(event["risk_level"]).to eq("standard")
      expect(event.dig("extra", "session_id")).to eq("integration-test-session")
      expect(event["reason"]).to be_nil
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
  end

  describe "denied evaluation (unknown capability) produces correct audit event" do
    it "denies unknown capability and logs the decision" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :nonexistent_capability
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:unknown_capability)

      event = audit_events.first
      expect(event["outcome"]).to eq("deny")
      expect(event["reason"]).to eq("unknown_capability")
      expect(event["risk_level"]).to eq("unknown")
    end
  end

  describe "denied evaluation (not granted) produces correct audit event" do
    it "denies ungranted caller and logs the decision" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :admin_tools
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:not_granted)

      event = audit_events.first
      expect(event["outcome"]).to eq("deny")
      expect(event["reason"]).to eq("not_granted")
      expect(event["risk_level"]).to eq("critical")
    end
  end

  describe "denied evaluation (prerequisite not met) produces correct audit event" do
    it "denies when prerequisite file is missing and logs the decision" do
      result = gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :privileged_introspection
      )

      expect(result).to be_denied
      expect(result.reason).to eq(:prerequisite_not_met)

      event = audit_events.first
      expect(event["outcome"]).to eq("deny")
      expect(event["reason"]).to eq("prerequisite_not_met")
      expect(event["prerequisites_passed"]).to be false
    end
  end

  describe "multiple evaluations produce sequential audit events" do
    it "logs every evaluation in order" do
      gate.evaluate(caller: "agent-1", capability: :basic_introspection)
      gate.evaluate(caller: "agent-2", capability: :nonexistent)
      gate.evaluate(caller: "agent-3", capability: :admin_tools)

      events = audit_events
      expect(events.size).to eq(3)
      expect(events.pluck("subject")).to eq(%w[agent-1 agent-2 agent-3])
      expect(events.pluck("outcome")).to eq(%w[allow deny deny])
    end
  end

  describe "capabilities listing works through public interface" do
    it "lists all capabilities from config" do
      names = gate.capabilities.map(&:name)

      expect(names).to contain_exactly(:basic_introspection, :privileged_introspection, :admin_tools)
    end

    it "exposes risk levels" do
      risk_map = gate.capabilities.to_h { |c| [c.name, c.risk_level] }

      expect(risk_map[:basic_introspection]).to eq(:standard)
      expect(risk_map[:privileged_introspection]).to eq(:elevated)
      expect(risk_map[:admin_tools]).to eq(:critical)
    end
  end

  describe "context flows through the full pipeline" do
    it "passes context to audit events" do
      gate.evaluate(
        caller: "service-account:introspection-agent",
        capability: :basic_introspection,
        context: { "environment" => "staging", "request_id" => "req-42" }
      )

      event = audit_events.first
      expect(event.dig("extra", "context")).to eq(
        "environment" => "staging",
        "request_id" => "req-42"
      )
    end
  end

  describe "fail-closed through the full pipeline" do
    it "returns denial when internal error occurs, does not raise" do
      gate_instance = Wild::CapabilityGate.new(
        config_path: config_path,
        audit_log_path: audit_log.path
      )

      broken_evaluator = instance_double(Wild::CapabilityGate::Evaluator)
      allow(broken_evaluator).to receive(:evaluate)
        .and_raise(RuntimeError, "simulated internal error")
      gate_instance.instance_variable_set(:@evaluator, broken_evaluator)

      result = gate_instance.evaluate(caller: "test", capability: :basic_introspection)

      expect(result).to be_denied
      expect(result.reason).to eq(:evaluation_error)
      expect(result.details).to include("RuntimeError")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
