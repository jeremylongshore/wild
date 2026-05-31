# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Triage::SeverityScorer do
  subject(:scorer) { described_class.new }

  let(:high_flake_record) do
    cause = Wild::Analyzers::TestFlakes::Models::RootCause.new(
      category: :timing_dependent, confidence: 0.8
    )
    flake_record_with(root_causes: [cause], flake_rate_numerator: 4, total: 5)
  end

  let(:low_flake_record) do
    flake_record_with(flake_rate_numerator: 1, total: 10)
  end

  describe "#score" do
    it "returns a float between 0 and 1" do
      score = scorer.score(high_flake_record)
      expect(score).to be >= 0.0
      expect(score).to be <= 1.0
    end

    it "scores high-flake records higher than low-flake records" do
      high_score = scorer.score(high_flake_record)
      low_score = scorer.score(low_flake_record)
      expect(high_score).to be > low_score
    end

    it "increases score for worsening trend" do
      stable = scorer.score(high_flake_record, trend: :stable)
      worsening = scorer.score(high_flake_record, trend: :worsening)
      expect(worsening).to be >= stable
    end

    it "decreases score for improving trend" do
      stable = scorer.score(high_flake_record, trend: :stable)
      improving = scorer.score(high_flake_record, trend: :improving)
      expect(improving).to be <= stable
    end
  end

  describe "#severity_from_score" do
    it "returns :critical for score >= 0.75" do
      expect(scorer.severity_from_score(0.8)).to eq(:critical)
    end

    it "returns :high for score in [0.5, 0.75)" do
      expect(scorer.severity_from_score(0.6)).to eq(:high)
    end

    it "returns :medium for score in [0.25, 0.5)" do
      expect(scorer.severity_from_score(0.35)).to eq(:medium)
    end

    it "returns :low for score < 0.25" do
      expect(scorer.severity_from_score(0.1)).to eq(:low)
    end
  end

  describe "with custom weights" do
    let(:scorer) do
      described_class.new(weights: { flake_rate: 3.0, failure_count: 1.0, trend: 1.0, confidence: 1.0 })
    end

    it "applies custom weights in scoring" do
      score = scorer.score(high_flake_record)
      expect(score).to be_a(Float)
    end
  end
end
