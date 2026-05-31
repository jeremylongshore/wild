# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Scoring::SeverityScorer do
  subject(:scorer) { described_class.new }

  describe "#score" do
    it "returns a Gap with adjusted severity" do
      gap = build_gap(type: :denial, severity: 0.5)
      scored = scorer.score(gap)
      expect(scored).to be_a(Wild::Telemetry::Analysis::Models::Gap)
    end

    it "applies the weight for the gap type" do
      Wild.configure { |c| c.telemetry.analysis.severity_weights = { denial: 2.0 } }
      scorer = described_class.new
      gap = build_gap(type: :denial, severity: 0.4)
      scored = scorer.score(gap)
      expect(scored.severity).to eq(0.8)
    end

    it "caps severity at 1.0 after weight application" do
      Wild.configure { |c| c.telemetry.analysis.severity_weights = { denial: 3.0 } }
      scorer = described_class.new
      gap = build_gap(type: :denial, severity: 0.8)
      scored = scorer.score(gap)
      expect(scored.severity).to eq(1.0)
    end

    it "applies 1.0 weight when type not in config" do
      gap = build_gap(type: :failure, severity: 0.6)
      scored = scorer.score(gap)
      expect(scored.severity).to eq(0.6)
    end

    it "preserves all other gap fields" do
      gap = build_gap(type: :denial, severity: 0.5, action: "my_action", description: "desc")
      scored = scorer.score(gap)
      expect(scored.action).to eq("my_action")
      expect(scored.description).to eq("desc")
    end
  end

  describe "#score_all" do
    it "scores each gap in the array" do
      gaps = [build_gap(type: :denial, severity: 0.3), build_gap(type: :failure, severity: 0.6)]
      scored = scorer.score_all(gaps)
      expect(scored.length).to eq(2)
      expect(scored).to all(be_a(Wild::Telemetry::Analysis::Models::Gap))
    end

    it "returns empty array when given empty array" do
      expect(scorer.score_all([])).to eq([])
    end
  end
end
