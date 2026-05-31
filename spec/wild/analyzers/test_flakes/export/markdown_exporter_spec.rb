# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Export::MarkdownExporter do
  subject(:exporter) { described_class.new }

  let(:entries) { [triage_entry, triage_entry(severity: :critical, score: 0.9)] }

  describe "#export" do
    it "returns a String" do
      result = exporter.export(entries)
      expect(result).to be_a(String)
    end

    it "includes the default title" do
      expect(exporter.export(entries)).to include("Flaky Test Triage Report")
    end

    it "accepts a custom title" do
      result = exporter.export(entries, title: "Custom Report")
      expect(result).to include("Custom Report")
    end

    it "includes a summary section" do
      expect(exporter.export(entries)).to include("## Summary")
    end

    it "includes severity table" do
      result = exporter.export(entries)
      expect(result).to include("Critical")
      expect(result).to include("High")
    end

    it "includes a flaky tests section" do
      expect(exporter.export(entries)).to include("## Flaky Tests")
    end

    it "includes each test name" do
      result = exporter.export(entries)
      entries.each do |entry|
        expect(result).to include(entry.test_identity.test_name)
      end
    end

    it "includes flake rate" do
      expect(exporter.export(entries)).to include("Flake Rate")
    end

    it "includes remediation suggestions" do
      expect(exporter.export(entries)).to include("Suggested Remediations")
    end

    context "with empty entries" do
      it "includes no flakes message" do
        result = exporter.export([])
        expect(result).to include("No flaky tests detected")
      end
    end

    context "with invalid input" do
      it "raises ExportError" do
        expect { exporter.export("bad") }.to raise_error(Wild::Analyzers::TestFlakes::ExportError)
      end
    end
  end
end
