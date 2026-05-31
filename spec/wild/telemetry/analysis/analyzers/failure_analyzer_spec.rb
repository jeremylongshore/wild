# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::FailureAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when failure rate exceeds threshold" do
      let(:util) { build_tool_utilization("success_rate" => 0.5) }
      let(:records) { { tool_utilization: [util] } }

      it "returns a failure gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :failure" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:failure)
      end

      it "sets severity to the failure rate" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to eq(0.5)
      end

      it "includes failure_rate in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:failure_rate]).to eq(0.5)
      end
    end

    context "when failure rate is below threshold" do
      let(:util) { build_tool_utilization("success_rate" => 0.95) }
      let(:records) { { tool_utilization: [util] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "with no tool_utilization records" do
      it "returns empty array" do
        expect(analyzer.analyze({})).to eq([])
      end
    end

    context "with custom failure threshold" do
      it "uses configured threshold" do
        Wild.configure { |c| c.telemetry.analysis.failure_threshold = 0.4 }
        analyzer = described_class.new
        util = build_tool_utilization("success_rate" => 0.7) # failure = 0.3, below 0.4
        gaps = analyzer.analyze({ tool_utilization: [util] })
        expect(gaps).to be_empty
      end
    end

    context "with 100% failure rate" do
      let(:util) { build_tool_utilization("success_rate" => 0.0) }
      let(:records) { { tool_utilization: [util] } }

      it "caps severity at 1.0" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to eq(1.0)
      end
    end
  end
end
