# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::History::TrendAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#trend_from_rates" do
    context "when flake rate is increasing" do
      it "returns :worsening" do
        rates = [0.1, 0.15, 0.2, 0.25, 0.3, 0.35]
        expect(analyzer.trend_from_rates(rates)).to eq(:worsening)
      end
    end

    context "when flake rate is decreasing" do
      it "returns :improving" do
        rates = [0.4, 0.35, 0.3, 0.2, 0.1, 0.05]
        expect(analyzer.trend_from_rates(rates)).to eq(:improving)
      end
    end

    context "when flake rate is stable" do
      it "returns :stable" do
        rates = [0.2, 0.21, 0.19, 0.20, 0.21, 0.20]
        expect(analyzer.trend_from_rates(rates)).to eq(:stable)
      end
    end

    context "with fewer than 2 rates" do
      it "returns :stable for single rate" do
        expect(analyzer.trend_from_rates([0.5])).to eq(:stable)
      end

      it "returns :stable for empty array" do
        expect(analyzer.trend_from_rates([])).to eq(:stable)
      end
    end
  end

  describe "#trend" do
    let(:base_time) { Time.utc(2024, 1, 1) }

    context "with worsening snapshots" do
      let(:snapshots) do
        rates = [0.1, 0.15, 0.2, 0.3, 0.4, 0.5]
        rates.each_with_index.map do |rate, i|
          { rate: rate, at: base_time + (i * 3600) }
        end
      end

      it "returns :worsening" do
        expect(analyzer.trend(snapshots)).to eq(:worsening)
      end
    end

    context "with improving snapshots" do
      let(:snapshots) do
        rates = [0.5, 0.4, 0.3, 0.2, 0.1, 0.05]
        rates.each_with_index.map do |rate, i|
          { rate: rate, at: base_time + (i * 3600) }
        end
      end

      it "returns :improving" do
        expect(analyzer.trend(snapshots)).to eq(:improving)
      end
    end

    context "with only one snapshot" do
      it "returns :stable" do
        expect(analyzer.trend([{ rate: 0.3, at: base_time }])).to eq(:stable)
      end
    end
  end
end
