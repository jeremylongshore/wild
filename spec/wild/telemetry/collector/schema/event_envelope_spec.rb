# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::Telemetry::Collector::Schema::EventEnvelope do
  subject(:envelope) do
    described_class.new(
      event_type: "action.completed",
      timestamp: "2026-03-19T14:30:00.000Z",
      caller_id: "service-account-ops",
      action: "retry_job",
      outcome: "success"
    )
  end

  describe ".new with required fields" do
    it "stores all required fields as readable attributes" do
      expect(envelope.event_type).to eq("action.completed")
      expect(envelope.timestamp).to eq("2026-03-19T14:30:00.000Z")
      expect(envelope.caller_id).to eq("service-account-ops")
      expect(envelope.action).to eq("retry_job")
      expect(envelope.outcome).to eq("success")
    end
  end

  describe "received_at default" do
    it "auto-sets received_at to a UTC ISO 8601 string" do
      expect(envelope.received_at).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "does not share received_at across separate instances" do
      first = described_class.new(**valid_action_completed_event)
      second = described_class.new(**valid_action_completed_event)
      expect(first.received_at).to be_a(String)
      expect(second.received_at).to be_a(String)
    end
  end

  describe "schema_version default" do
    it "defaults schema_version to '1.0'" do
      expect(envelope.schema_version).to eq("1.0")
    end

    it "accepts a custom schema_version" do
      versioned = described_class.new(**valid_action_completed_event, schema_version: "2.0")
      expect(versioned.schema_version).to eq("2.0")
    end
  end

  describe "metadata default" do
    it "defaults metadata to an empty hash when nil is passed" do
      expect(envelope.metadata).to eq({})
    end

    it "defaults metadata to an empty hash when omitted" do
      omitted = described_class.new(
        event_type: "action.completed",
        timestamp: "2026-03-19T14:30:00.000Z",
        caller_id: "service-account-ops",
        action: "retry_job",
        outcome: "success"
      )
      expect(omitted.metadata).to eq({})
    end
  end

  describe "optional duration_ms" do
    it "stores duration_ms when provided" do
      with_duration = described_class.new(**valid_action_completed_event, duration_ms: 42.5)
      expect(with_duration.duration_ms).to eq(42.5)
    end

    it "defaults duration_ms to nil when omitted" do
      expect(envelope.duration_ms).to be_nil
    end
  end

  describe "immutability" do
    it "is frozen after initialization" do
      expect(envelope).to be_frozen
    end

    it "freezes the metadata hash" do
      with_meta = described_class.new(**valid_action_completed_event)
      expect(with_meta.metadata).to be_frozen
    end
  end

  describe "#to_h" do
    subject(:hash) { described_class.new(**valid_action_completed_event).to_h }

    it "returns a Hash with all expected keys" do
      expected_keys = %i[event_type timestamp caller_id action outcome duration_ms metadata received_at schema_version]
      expect(hash.keys).to match_array(expected_keys)
    end

    it "maps field values correctly" do
      expect(hash[:event_type]).to eq("action.completed")
      expect(hash[:caller_id]).to eq("service-account-ops")
      expect(hash[:outcome]).to eq("success")
    end

    it "returns an unfrozen copy of metadata" do
      expect(hash[:metadata]).not_to be_frozen
    end
  end

  describe ".from_raw" do
    let(:raw_hash) do
      {
        "event_type" => "action.completed",
        "timestamp" => "2026-03-19T14:30:00.000Z",
        "caller_id" => "service-account-ops",
        "action" => "retry_job",
        "outcome" => "success",
        "duration_ms" => 42.5,
        "metadata" => { "category" => "background_jobs" }
      }
    end

    it "creates an EventEnvelope from a string-keyed hash" do
      result = described_class.from_raw(raw_hash)
      expect(result).to be_a(described_class)
      expect(result.event_type).to eq("action.completed")
      expect(result.caller_id).to eq("service-account-ops")
    end

    it "correctly maps optional fields from string keys" do
      result = described_class.from_raw(raw_hash)
      expect(result.duration_ms).to eq(42.5)
    end

    it "returns a frozen instance" do
      result = described_class.from_raw(raw_hash)
      expect(result).to be_frozen
    end
  end
end
