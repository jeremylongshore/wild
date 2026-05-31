# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::EventRecord do
  subject(:event) { build_event }

  describe "attribute readers" do
    it "exposes event_type" do
      expect(event.event_type).to eq("tool_call")
    end

    it "exposes caller_id" do
      expect(event.caller_id).to eq("caller-001")
    end

    it "exposes action" do
      expect(event.action).to eq("read_file")
    end

    it "exposes outcome" do
      expect(event.outcome).to eq("success")
    end

    it "exposes duration_ms" do
      expect(event.duration_ms).to eq(50)
    end

    it "defaults metadata to empty hash" do
      e = build_event("metadata" => nil)
      expect(e.metadata).to eq({})
    end
  end

  describe "#success?" do
    it "returns true when outcome is success" do
      expect(event).to be_success
    end

    it "returns false when outcome is denied" do
      expect(build_event("outcome" => "denied")).not_to be_success
    end
  end

  describe "#denied?" do
    it "returns true when outcome is denied" do
      expect(build_event("outcome" => "denied")).to be_denied
    end

    it "returns false when outcome is success" do
      expect(event).not_to be_denied
    end
  end

  describe "#error?" do
    it "returns true when outcome is error" do
      expect(build_event("outcome" => "error")).to be_error
    end

    it "returns false for success" do
      expect(event).not_to be_error
    end
  end

  describe "#rate_limited?" do
    it "returns true when outcome is rate_limited" do
      expect(build_event("outcome" => "rate_limited")).to be_rate_limited
    end

    it "returns false for success" do
      expect(event).not_to be_rate_limited
    end
  end

  describe "record_type" do
    it "is event" do
      expect(event.record_type).to eq("event")
    end
  end
end
