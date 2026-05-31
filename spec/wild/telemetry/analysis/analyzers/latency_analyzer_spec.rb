# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::LatencyAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when p95 exceeds threshold" do
      let(:stat) { build_latency_stats("p95_ms" => 600.0) }
      let(:records) { { latency_stats: [stat] } }

      it "returns a latency gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :latency" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:latency)
      end

      it "includes p95_ms in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:p95_ms]).to eq(600.0)
      end

      it "includes threshold_ms in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:threshold_ms]).to eq(500.0)
      end
    end

    context "when p95 is below threshold" do
      let(:stat) { build_latency_stats("p95_ms" => 200.0) }
      let(:records) { { latency_stats: [stat] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "when p95 is exactly at threshold" do
      let(:stat) { build_latency_stats("p95_ms" => 500.0) }
      let(:records) { { latency_stats: [stat] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "with no latency_stats records" do
      it "returns empty array" do
        expect(analyzer.analyze({})).to eq([])
      end
    end

    context "with custom latency threshold" do
      it "uses configured threshold" do
        Wild.configure { |c| c.telemetry.analysis.latency_p95_threshold_ms = 100.0 }
        analyzer = described_class.new
        stat = build_latency_stats("p95_ms" => 150.0)
        gaps = analyzer.analyze({ latency_stats: [stat] })
        expect(gaps).not_to be_empty
      end
    end

    context "with p95 at 2x threshold (severity saturation)" do
      let(:stat) { build_latency_stats("p95_ms" => 1000.0) }
      let(:records) { { latency_stats: [stat] } }

      it "caps severity at 1.0" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to eq(1.0)
      end
    end
  end
end
