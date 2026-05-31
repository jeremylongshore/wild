# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::GapReport do
  subject(:report) { described_class.new(header: header, gaps: gaps) }

  let(:header) { build_header }
  let(:gaps) do
    [
      build_gap(type: :denial, action: "tool_a", severity: 0.8),
      build_gap(type: :failure, action: "tool_b", severity: 0.6),
      build_gap(type: :latency, action: "tool_a", severity: 0.9)
    ]
  end

  describe "#gaps" do
    it "sorts gaps by severity descending" do
      severities = report.gaps.map(&:severity)
      expect(severities).to eq(severities.sort.reverse)
    end
  end

  describe "#gaps_of_type" do
    it "returns only gaps of the specified type" do
      denial_gaps = report.gaps_of_type(:denial)
      expect(denial_gaps.map(&:type).uniq).to eq([:denial])
    end

    it "returns empty array when no gaps of that type" do
      expect(report.gaps_of_type(:pattern)).to eq([])
    end
  end

  describe "#summary" do
    it "includes total_gaps" do
      expect(report.summary[:total_gaps]).to eq(3)
    end

    it "includes by_type counts" do
      expect(report.summary[:by_type][:denial]).to eq(1)
    end

    it "includes severity_avg" do
      expect(report.summary[:severity_avg]).to be_a(Float)
    end

    it "includes high_severity_count" do
      expect(report.summary[:high_severity_count]).to eq(2) # 0.8 and 0.9
    end

    it "includes top_actions" do
      top = report.summary[:top_actions]
      expect(top).to be_an(Array)
      expect(top.first[:action]).to eq("tool_a")
    end
  end

  describe "#to_h" do
    it "returns a hash with header, gaps, summary, and generated_at" do
      h = report.to_h
      expect(h.keys).to include(:header, :gaps, :summary, :generated_at)
    end

    it "serializes gaps as hashes" do
      expect(report.to_h[:gaps].first).to be_a(Hash)
    end
  end

  describe "with empty gaps" do
    subject(:empty_report) { described_class.new(header: header, gaps: []) }

    it "has severity_avg of 0.0" do
      expect(empty_report.summary[:severity_avg]).to eq(0.0)
    end

    it "has empty top_actions" do
      expect(empty_report.summary[:top_actions]).to eq([])
    end
  end
end
