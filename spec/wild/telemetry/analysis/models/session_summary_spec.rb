# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::SessionSummary do
  subject(:summary) { build_session_summary }

  describe "attribute readers" do
    it "exposes caller_id" do
      expect(summary.caller_id).to eq("caller-001")
    end

    it "exposes event_count" do
      expect(summary.event_count).to eq(10)
    end

    it "exposes distinct_actions" do
      expect(summary.distinct_actions).to eq(%w[read_file write_file list_dir])
    end

    it "exposes outcome_breakdown" do
      expect(summary.outcome_breakdown).to eq({ "success" => 8, "denied" => 2 })
    end

    it "defaults event_count to 0" do
      expect(build_session_summary("event_count" => nil).event_count).to eq(0)
    end

    it "defaults distinct_actions to empty array" do
      expect(build_session_summary("distinct_actions" => nil).distinct_actions).to eq([])
    end
  end

  describe "#action_count" do
    it "returns the number of distinct actions" do
      expect(summary.action_count).to eq(3)
    end

    it "returns 0 when no distinct actions" do
      expect(build_session_summary("distinct_actions" => []).action_count).to eq(0)
    end
  end

  describe "record_type" do
    it "is session_summary" do
      expect(summary.record_type).to eq("session_summary")
    end
  end
end
