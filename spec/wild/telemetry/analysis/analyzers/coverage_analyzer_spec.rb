# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::CoverageAnalyzer do
  subject(:analyzer) { described_class.new }

  let(:all_utils) do
    %w[read_file write_file list_dir delete_file exec_cmd grep_file].map do |action|
      build_tool_utilization("action" => action, "invocation_count" => 10)
    end
  end

  describe "#analyze" do
    context "when caller uses fewer actions than coverage minimum" do
      let(:session) { build_session_summary("distinct_actions" => ["read_file"]) }
      let(:records) { { session_summary: [session], tool_utilization: all_utils } }

      it "returns a coverage gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :coverage" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:coverage)
      end

      it "includes coverage_fraction in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:coverage_fraction]).to be < 0.3
      end

      it "uses caller_id as the action label" do
        gap = analyzer.analyze(records).first
        expect(gap.action).to eq("caller-001")
      end
    end

    context "when caller meets coverage minimum" do
      let(:session) do
        build_session_summary("distinct_actions" => %w[read_file write_file list_dir delete_file])
      end
      let(:records) { { session_summary: [session], tool_utilization: all_utils } }

      it "returns no gaps" do
        # 4/6 = 0.667, above 0.3 threshold
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "with no session_summary records" do
      it "returns empty array" do
        expect(analyzer.analyze({ tool_utilization: all_utils })).to eq([])
      end
    end

    context "with no tool_utilization records" do
      it "returns empty array" do
        session = build_session_summary
        expect(analyzer.analyze({ session_summary: [session] })).to eq([])
      end
    end

    context "with custom coverage_min_fraction" do
      it "uses configured minimum" do
        Wild.configure { |c| c.telemetry.analysis.coverage_min_fraction = 0.8 }
        analyzer = described_class.new
        session = build_session_summary("distinct_actions" => %w[read_file write_file list_dir])
        gaps = analyzer.analyze({ session_summary: [session], tool_utilization: all_utils })
        expect(gaps).not_to be_empty
      end
    end
  end
end
