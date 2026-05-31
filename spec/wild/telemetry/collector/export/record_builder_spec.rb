# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Collector::Export::RecordBuilder do
  subject(:builder) { described_class.new }

  describe "#header" do
    it "builds a header with all required fields" do
      header = builder.header(
        schema_version: "1.0.0",
        exported_at: "2026-03-19T15:00:00.000Z",
        time_range: { start: "2026-03-12T00:00:00Z", end: "2026-03-19T15:00:00Z" },
        record_counts: { events: 10 }
      )
      expect(header[:export_type]).to eq("session_telemetry")
      expect(header[:schema_version]).to eq("1.0.0")
      expect(header[:exported_at]).to eq("2026-03-19T15:00:00.000Z")
      expect(header[:time_range][:start]).to eq("2026-03-12T00:00:00Z")
      expect(header[:record_counts][:events]).to eq(10)
    end
  end

  describe "#event_record" do
    it "builds an event record from an envelope" do
      envelope = build_envelope
      record = builder.event_record(envelope)
      expect(record[:record_type]).to eq("event")
      expect(record[:event_type]).to eq("action.completed")
      expect(record[:action]).to eq("retry_job")
    end

    it "includes metadata in the event record" do
      envelope = build_envelope(metadata: { category: "jobs" })
      record = builder.event_record(envelope)
      expect(record[:metadata]).to include(category: "jobs")
    end

    it "excludes received_at and schema_version from event records" do
      envelope = build_envelope
      record = builder.event_record(envelope)
      expect(record).not_to have_key(:received_at)
      expect(record).not_to have_key(:schema_version)
    end
  end

  describe "#session_summary_record" do
    it "adds record_type to summary hash" do
      record = builder.session_summary_record(caller_id: "ops", event_count: 10)
      expect(record[:record_type]).to eq("session_summary")
      expect(record[:caller_id]).to eq("ops")
    end
  end

  describe "#tool_utilization_record" do
    it "adds record_type to utilization hash" do
      record = builder.tool_utilization_record(action: "retry_job", invocation_count: 5)
      expect(record[:record_type]).to eq("tool_utilization")
      expect(record[:action]).to eq("retry_job")
    end
  end

  describe "#outcome_distribution_record" do
    it "adds record_type to distribution hash" do
      record = builder.outcome_distribution_record(action: "retry_job", total_count: 100)
      expect(record[:record_type]).to eq("outcome_distribution")
    end
  end

  describe "#latency_stats_record" do
    it "adds record_type to stats hash" do
      record = builder.latency_stats_record(action: "retry_job", p50: 35.2)
      expect(record[:record_type]).to eq("latency_stats")
    end
  end

  describe "#pattern_record" do
    it "adds record_type to pattern hash" do
      record = builder.pattern_record(sequence: %w[inspect retry], occurrence_count: 5)
      expect(record[:record_type]).to eq("pattern")
      expect(record[:sequence]).to eq(%w[inspect retry])
    end
  end
end
