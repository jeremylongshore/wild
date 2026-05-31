# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::OutcomeDistribution do
  subject(:dist) { build_outcome_distribution }

  describe "attribute readers" do
    it "exposes action" do
      expect(dist.action).to eq("read_file")
    end

    it "exposes total_count" do
      expect(dist.total_count).to eq(20)
    end

    it "accepts outcomes key from upstream contract" do
      d = build_outcome_distribution("outcomes" => { "success" => 0.9 })
      expect(d.distribution["success"]).to eq(0.9)
    end

    it "defaults distribution to empty hash" do
      d = described_class.new("record_type" => "outcome_distribution", "action" => "x")
      expect(d.distribution).to eq({})
    end
  end

  describe "#percentage_for" do
    it "returns the value for a known outcome" do
      expect(dist.percentage_for("success")).to eq(0.8)
    end

    it "returns 0.0 for unknown outcomes" do
      expect(dist.percentage_for("preview")).to eq(0.0)
    end

    it "accepts symbol keys" do
      expect(dist.percentage_for(:denied)).to eq(0.1)
    end
  end

  describe "record_type" do
    it "is outcome_distribution" do
      expect(dist.record_type).to eq("outcome_distribution")
    end
  end
end
