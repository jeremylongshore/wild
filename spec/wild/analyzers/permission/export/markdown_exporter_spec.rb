# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Export::MarkdownExporter do
  subject(:exporter) { described_class.new }

  let(:report) do
    Wild::Analyzers::Permission::Report::Builder.new(standard_capabilities, standard_grants).build
  end

  describe "#export" do
    it "returns a non-empty string" do
      output = exporter.export(report)
      expect(output).to be_a(String)
      expect(output).not_to be_empty
    end

    it "includes a top-level header" do
      output = exporter.export(report)
      expect(output).to include("# Permission Audit Report")
    end

    it "includes a summary section" do
      output = exporter.export(report)
      expect(output).to include("## Summary")
    end

    it "includes a findings section" do
      output = exporter.export(report)
      expect(output).to include("## Findings")
    end

    it "includes a coverage section" do
      output = exporter.export(report)
      expect(output).to include("## Coverage")
    end

    it "includes severity labels in findings table" do
      output = exporter.export(report)
      expect(output).to match(/CRITICAL|ERROR|WARN|INFO/)
    end

    it "escapes pipe characters in messages" do
      finding = Wild::Analyzers::Permission::Models::Finding.new(
        type: :foo, severity: :info, message: "has | pipe in message"
      )
      empty_report = Wild::Analyzers::Permission::Models::AuditReport.new(
        findings: [finding], coverage_reports: []
      )
      output = exporter.export(empty_report)
      expect(output).to include('\\|')
    end

    it "raises ExportError for non-AuditReport input" do
      expect { exporter.export(nil) }
        .to raise_error(Wild::Analyzers::Permission::ExportError)
    end

    context "with no findings" do
      it "outputs No findings message" do
        empty = Wild::Analyzers::Permission::Models::AuditReport.new(findings: [], coverage_reports: [])
        expect(exporter.export(empty)).to include("No findings.")
      end
    end

    context "with no coverage reports" do
      it "outputs No coverage data message" do
        empty = Wild::Analyzers::Permission::Models::AuditReport.new(findings: [], coverage_reports: [])
        expect(exporter.export(empty)).to include("No coverage data.")
      end
    end
  end
end
