# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Export::MarkdownExporter do
  subject(:exporter) { described_class.new }

  let(:report) do
    Wild::Telemetry::Analysis::Models::GapReport.new(
      header: build_header,
      gaps: [
        build_gap(type: :denial, severity: 0.9, action: "tool_a", description: "High denial rate"),
        build_gap(type: :failure, severity: 0.5, action: "tool_b", description: "Medium failure")
      ],
      generated_at: "2025-01-15T10:00:00Z"
    )
  end

  describe "#export" do
    it "returns a String" do
      expect(exporter.export(report)).to be_a(String)
    end

    it "starts with a heading" do
      expect(exporter.export(report)).to start_with("# Gap Analysis Report")
    end

    it "includes Generated timestamp" do
      expect(exporter.export(report)).to include("2025-01-15T10:00:00Z")
    end

    it "includes Summary section" do
      expect(exporter.export(report)).to include("## Summary")
    end

    it "includes Gaps section" do
      expect(exporter.export(report)).to include("## Gaps")
    end

    it "includes gap action in output" do
      expect(exporter.export(report)).to include("tool_a")
    end

    it "shows HIGH for high severity gap" do
      expect(exporter.export(report)).to include("[HIGH]")
    end

    it "shows MEDIUM for medium severity gap" do
      expect(exporter.export(report)).to include("[MEDIUM]")
    end

    it "shows evidence section" do
      expect(exporter.export(report)).to include("**Evidence**")
    end
  end

  describe "with empty report" do
    let(:empty_report) do
      Wild::Telemetry::Analysis::Models::GapReport.new(header: build_header, gaps: [])
    end

    it "shows no gaps detected message" do
      expect(exporter.export(empty_report)).to include("No gaps detected")
    end
  end

  describe "#write" do
    it "writes markdown to file and returns path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "report.md")
        result = exporter.write(report, path)
        expect(result).to eq(path)
        expect(File.exist?(path)).to be(true)
      end
    end

    it "writes readable markdown content" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "report.md")
        exporter.write(report, path)
        content = File.read(path)
        expect(content).to include("# Gap Analysis Report")
      end
    end
  end
end
