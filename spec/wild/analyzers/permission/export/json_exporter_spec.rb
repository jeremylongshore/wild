# frozen_string_literal: true

require "json"

RSpec.describe Wild::Analyzers::Permission::Export::JsonExporter do
  subject(:exporter) { described_class.new }

  let(:report) do
    Wild::Analyzers::Permission::Report::Builder.new(standard_capabilities, standard_grants).build
  end

  describe "#export" do
    it "returns a valid JSON string" do
      output = exporter.export(report)
      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes generated_at" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["generated_at"]).to be_a(String)
    end

    it "includes summary with total_findings" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["summary"]["total_findings"]).to be_an(Integer)
    end

    it "includes findings array" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["findings"]).to be_an(Array)
    end

    it "includes coverage_reports array" do
      parsed = JSON.parse(exporter.export(report))
      expect(parsed["coverage_reports"]).to be_an(Array)
    end

    it "each finding has type, severity, message, evidence" do
      parsed = JSON.parse(exporter.export(report))
      finding = parsed["findings"].first
      expect(finding.keys).to include("type", "severity", "message", "evidence")
    end

    it "each coverage report has caller_id and coverage_ratio" do
      parsed = JSON.parse(exporter.export(report))
      coverage = parsed["coverage_reports"].first
      expect(coverage.keys).to include("caller_id", "coverage_ratio")
    end

    it "raises ExportError for non-AuditReport input" do
      expect { exporter.export("not a report") }
        .to raise_error(Wild::Analyzers::Permission::ExportError)
    end

    context "with empty findings" do
      it "exports an empty findings array" do
        empty_report = Wild::Analyzers::Permission::Models::AuditReport.new(
          findings: [], coverage_reports: []
        )
        parsed = JSON.parse(exporter.export(empty_report))
        expect(parsed["findings"]).to be_empty
      end
    end
  end
end
