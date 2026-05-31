# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::UtilizationAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when invocation_count is below minimum" do
      let(:util) { build_tool_utilization("invocation_count" => 2) }
      let(:records) { { tool_utilization: [util] } }

      it "returns a utilization gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :utilization" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:utilization)
      end

      it "includes invocation_count in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:invocation_count]).to eq(2)
      end
    end

    context "when invocation_count meets the minimum" do
      let(:util) { build_tool_utilization("invocation_count" => 10) }
      let(:records) { { tool_utilization: [util] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "when invocation_count is zero" do
      let(:util) { build_tool_utilization("invocation_count" => 0) }
      let(:records) { { tool_utilization: [util] } }

      it "returns a gap with severity 1.0" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to eq(1.0)
      end
    end

    context "with no tool_utilization records" do
      it "returns empty array" do
        expect(analyzer.analyze({})).to eq([])
      end
    end

    context "with custom utilization min count" do
      it "uses configured min count" do
        Wild.configure { |c| c.telemetry.analysis.utilization_min_count = 20 }
        analyzer = described_class.new
        util = build_tool_utilization("invocation_count" => 15)
        gaps = analyzer.analyze({ tool_utilization: [util] })
        expect(gaps).not_to be_empty
      end
    end
  end
end
