# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Scoring::PriorityRanker do
  subject(:ranker) { described_class.new }

  let(:gaps) do
    [
      build_gap(severity: 0.3),
      build_gap(severity: 0.9),
      build_gap(severity: 0.6)
    ]
  end

  describe "#rank" do
    it "returns a ranked array of hashes" do
      ranked = ranker.rank(gaps)
      expect(ranked).to all(include(:rank, :gap))
    end

    it "assigns rank 1 to highest severity" do
      ranked = ranker.rank(gaps)
      expect(ranked.first[:gap].severity).to eq(0.9)
      expect(ranked.first[:rank]).to eq(1)
    end

    it "assigns sequential ranks" do
      ranked = ranker.rank(gaps)
      expect(ranked.pluck(:rank)).to eq([1, 2, 3])
    end

    it "returns empty array for empty input" do
      expect(ranker.rank([])).to eq([])
    end
  end

  describe "#sort" do
    it "returns gaps sorted by severity descending" do
      sorted = ranker.sort(gaps)
      expect(sorted.map(&:severity)).to eq([0.9, 0.6, 0.3])
    end
  end
end
