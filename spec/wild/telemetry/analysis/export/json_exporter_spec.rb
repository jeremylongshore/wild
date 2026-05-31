# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Export::JsonExporter do
  subject(:exporter) { described_class.new }

  let(:report) do
    Wild::Telemetry::Analysis::Models::GapReport.new(
      header: build_header,
      gaps: [build_gap(severity: 0.7)],
      generated_at: "2025-01-15T10:00:00Z"
    )
  end

  describe "#export" do
    it "returns a JSON string" do
      json = exporter.export(report)
      expect { JSON.parse(json) }.not_to raise_error
    end

    it "includes header data" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["header"]).not_to be_nil
    end

    it "includes gaps array" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["gaps"]).to be_an(Array)
    end

    it "includes generated_at" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["generated_at"]).to eq("2025-01-15T10:00:00Z")
    end

    it "includes summary" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["summary"]).to include("total_gaps")
    end
  end

  describe "#write" do
    it "writes JSON to file and returns path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "report.json")
        result = exporter.write(report, path)
        expect(result).to eq(path)
        expect(File.exist?(path)).to be(true)
      end
    end

    it "writes valid JSON" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "report.json")
        exporter.write(report, path)
        expect { JSON.parse(File.read(path)) }.not_to raise_error
      end
    end
  end
end
