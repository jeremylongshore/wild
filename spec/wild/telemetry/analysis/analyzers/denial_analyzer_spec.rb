# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::DenialAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when denial rate exceeds threshold" do
      let(:dist) { build_outcome_distribution("outcomes" => { "success" => 0.5, "denied" => 0.5 }) }
      let(:records) { { outcome_distribution: [dist] } }

      it "returns a denial gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :denial" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:denial)
      end

      it "sets severity to the denial rate" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to eq(0.5)
      end

      it "includes denial_rate in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:denial_rate]).to eq(0.5)
      end

      it "includes a recommendation" do
        gap = analyzer.analyze(records).first
        expect(gap.recommendation).not_to be_nil
      end
    end

    context "when denial rate is below threshold" do
      let(:dist) { build_outcome_distribution("outcomes" => { "success" => 0.98, "denied" => 0.02 }) }
      let(:records) { { outcome_distribution: [dist] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "when denial rate exactly equals threshold" do
      let(:dist) { build_outcome_distribution("outcomes" => { "success" => 0.8, "denied" => 0.2 }) }
      let(:records) { { outcome_distribution: [dist] } }

      it "returns a gap" do
        expect(analyzer.analyze(records)).not_to be_empty
      end
    end

    context "with no outcome_distribution records" do
      it "returns empty array" do
        expect(analyzer.analyze({})).to eq([])
      end
    end

    context "when max_gaps_per_type is set" do
      it "limits to configured maximum" do
        Wild.configure { |c| c.telemetry.analysis.max_gaps_per_type = 1 }
        analyzer = described_class.new
        dists = [
          build_outcome_distribution("action" => "a", "outcomes" => { "denied" => 0.9 }),
          build_outcome_distribution("action" => "b", "outcomes" => { "denied" => 0.8 })
        ]
        gaps = analyzer.analyze({ outcome_distribution: dists })
        expect(gaps.length).to be <= 1
      end
    end
  end
end
