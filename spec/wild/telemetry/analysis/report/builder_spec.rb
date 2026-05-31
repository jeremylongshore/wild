# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Report::Builder do
  subject(:builder) { described_class.new(records: records) }

  let(:header) { build_header }
  let(:records) do
    {
      header: header,
      outcome_distribution: [
        build_outcome_distribution("action" => "high_denial", "outcomes" => { "denied" => 0.8, "success" => 0.2 })
      ],
      tool_utilization: [
        build_tool_utilization("action" => "low_success", "success_rate" => 0.5, "invocation_count" => 10)
      ],
      latency_stats: [
        build_latency_stats("action" => "slow_action", "p95_ms" => 800.0)
      ],
      session_summary: [build_session_summary],
      pattern: [build_pattern_record]
    }
  end

  describe "#build" do
    it "returns a GapReport" do
      report = builder.build
      expect(report).to be_a(Wild::Telemetry::Analysis::Models::GapReport)
    end

    it "populates gaps from all analyzers" do
      report = builder.build
      expect(report.gaps).not_to be_empty
    end

    it "includes denial gaps" do
      report = builder.build
      expect(report.gaps_of_type(:denial)).not_to be_empty
    end

    it "includes failure gaps" do
      report = builder.build
      expect(report.gaps_of_type(:failure)).not_to be_empty
    end

    it "includes latency gaps" do
      report = builder.build
      expect(report.gaps_of_type(:latency)).not_to be_empty
    end

    it "passes the header to the GapReport" do
      report = builder.build
      expect(report.header).to eq(header)
    end

    it "gaps are scored" do
      report = builder.build
      expect(report.gaps.map(&:severity)).to all(be_between(0.0, 1.0))
    end

    it "all gaps have recommendations" do
      report = builder.build
      expect(report.gaps.map(&:recommendation)).to all(be_a(String))
    end
  end

  describe "with empty records" do
    subject(:empty_builder) { described_class.new(records: { header: header }) }

    it "returns a GapReport with no gaps" do
      report = empty_builder.build
      expect(report.gaps).to be_empty
    end
  end

  describe "with custom config" do
    it "passes config to analyzers" do
      Wild.configure { |c| c.telemetry.analysis.failure_threshold = 0.9 }
      builder = described_class.new(records: records)
      report = builder.build
      # With 90% failure threshold, the 50% failure rate won't trigger
      expect(report.gaps_of_type(:failure)).to be_empty
    end
  end
end
