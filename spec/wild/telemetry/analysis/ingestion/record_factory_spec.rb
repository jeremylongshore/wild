# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Ingestion::RecordFactory do
  describe ".build" do
    it "builds an EventRecord for record_type event" do
      record = described_class.build("record_type" => "event", "action" => "x", "outcome" => "success")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::EventRecord)
    end

    it "builds a SessionSummary for record_type session_summary" do
      record = described_class.build("record_type" => "session_summary", "caller_id" => "c1")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::SessionSummary)
    end

    it "builds a ToolUtilization for record_type tool_utilization" do
      record = described_class.build("record_type" => "tool_utilization", "action" => "x")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::ToolUtilization)
    end

    it "builds an OutcomeDistribution for record_type outcome_distribution" do
      record = described_class.build("record_type" => "outcome_distribution", "action" => "x")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::OutcomeDistribution)
    end

    it "builds a LatencyStats for record_type latency_stats" do
      record = described_class.build("record_type" => "latency_stats", "action" => "x")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::LatencyStats)
    end

    it "builds a PatternRecord for record_type pattern" do
      record = described_class.build("record_type" => "pattern", "pattern_type" => "loop")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::PatternRecord)
    end

    it "builds a TelemetryRecord for unknown record_type" do
      record = described_class.build("record_type" => "unknown_type")
      expect(record).to be_a(Wild::Telemetry::Analysis::Models::TelemetryRecord)
    end

    it "sets record_type on the built record" do
      record = described_class.build("record_type" => "event", "action" => "x", "outcome" => "success")
      expect(record.record_type).to eq("event")
    end
  end
end
