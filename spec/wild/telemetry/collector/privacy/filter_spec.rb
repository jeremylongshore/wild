# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::Telemetry::Collector::Privacy::Filter do
  subject(:filter) { described_class.new }

  describe "with a clean action.completed event" do
    it "passes through all allowed top-level keys unchanged" do
      result = filter.filter(valid_action_completed_event)
      expect(result[:event_type]).to eq("action.completed")
      expect(result[:caller_id]).to eq("service-account-ops")
      expect(result[:outcome]).to eq("success")
    end

    it "passes through all allowed metadata keys unchanged" do
      result = filter.filter(valid_action_completed_event)
      expect(result[:metadata]).to include(:category, :operation)
    end
  end

  describe "with a clean gate.evaluated event" do
    it "passes through all allowed keys unchanged" do
      result = filter.filter(valid_gate_evaluated_event)
      expect(result[:event_type]).to eq("gate.evaluated")
      expect(result[:metadata]).to include(:gate_result, :capability_checked)
    end
  end

  describe "with a clean rate_limit.checked event" do
    it "passes through all allowed keys unchanged" do
      result = filter.filter(valid_rate_limit_checked_event)
      expect(result[:event_type]).to eq("rate_limit.checked")
      expect(result[:metadata]).to include(:rate_result, :current_count, :limit, :window_seconds)
    end
  end

  describe "when the event has unknown top-level fields" do
    it "strips fields not in the top-level allowlist" do
      event = valid_action_completed_event.merge(
        user_ip: "192.168.1.1",
        session_token: "abc123",
        internal_ref: "ref-99"
      )
      result = filter.filter(event)
      expect(result.keys).not_to include(:user_ip, :session_token, :internal_ref)
    end

    it "retains all allowed top-level fields after stripping" do
      event = valid_action_completed_event.merge(forbidden: "data")
      result = filter.filter(event)
      expect(result).to include(:event_type, :timestamp, :caller_id, :action, :outcome)
    end
  end

  describe "when action.completed metadata has unknown keys" do
    it "strips metadata keys not in the action.completed allowlist" do
      event = valid_action_completed_event.merge(
        metadata: { category: "background_jobs", operation: "mutate", raw_params: { id: 42 } }
      )
      result = filter.filter(event)
      expect(result[:metadata].keys).not_to include(:raw_params)
      expect(result[:metadata]).to include(:category, :operation)
    end
  end

  describe "when gate.evaluated metadata has unknown keys" do
    it "strips metadata keys not in the gate.evaluated allowlist" do
      event = valid_gate_evaluated_event.merge(
        metadata: {
          gate_result: "allowed",
          capability_checked: "admin_tools.retry_job",
          raw_user_context: "sensitive"
        }
      )
      result = filter.filter(event)
      expect(result[:metadata].keys).not_to include(:raw_user_context)
      expect(result[:metadata]).to include(:gate_result, :capability_checked)
    end
  end

  describe "when rate_limit.checked metadata has unknown keys" do
    it "strips metadata keys not in the rate_limit.checked allowlist" do
      event = valid_rate_limit_checked_event.merge(
        metadata: {
          rate_result: "allowed",
          current_count: 7,
          limit: 10,
          window_seconds: 60,
          requester_ip: "10.0.0.1"
        }
      )
      result = filter.filter(event)
      expect(result[:metadata].keys).not_to include(:requester_ip)
      expect(result[:metadata]).to include(:rate_result, :current_count, :limit, :window_seconds)
    end
  end

  describe "when metadata is nil" do
    it "returns the event without a metadata key modification" do
      event = valid_action_completed_event.merge(metadata: nil)
      result = filter.filter(event)
      expect(result[:metadata]).to be_nil
    end
  end

  describe "when metadata is absent from the event" do
    it "does not raise and leaves metadata absent or nil" do
      event = valid_action_completed_event.except(:metadata)
      expect { filter.filter(event) }.not_to raise_error
    end
  end

  describe "when metadata is empty" do
    it "returns an empty metadata hash" do
      event = valid_action_completed_event.merge(metadata: {})
      result = filter.filter(event)
      expect(result[:metadata]).to eq({})
    end
  end
end
