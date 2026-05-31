# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Export::SummaryExporter do
  subject(:exporter) { described_class.new }

  let(:entries) { [triage_entry(severity: :critical, score: 0.9), triage_entry] }

  describe "#export" do
    it "returns a String ending in newline" do
      result = exporter.export(entries)
      expect(result).to be_a(String)
      expect(result).to end_with("\n")
    end

    it "includes FLAKE REPORT header" do
      expect(exporter.export(entries)).to include("FLAKE REPORT")
    end

    it "includes total count" do
      expect(exporter.export(entries)).to include("2 flaky test")
    end

    it "includes severity labels" do
      result = exporter.export(entries)
      expect(result).to include("[CRITICAL]").or include("[HIGH]")
    end

    it "includes test names" do
      result = exporter.export(entries)
      entries.each do |entry|
        # Name may be truncated; check prefix
        name_prefix = entry.test_identity.test_name[0, 20]
        expect(result).to include(name_prefix)
      end
    end

    it "includes flake percentage" do
      expect(exporter.export(entries)).to match(/\d+\.\d+%/)
    end

    context "with empty entries" do
      it "returns a no-flakes message" do
        result = exporter.export([])
        expect(result).to include("No flaky tests detected")
      end
    end

    context "with invalid input" do
      it "raises ExportError" do
        expect { exporter.export("bad") }.to raise_error(Wild::Analyzers::TestFlakes::ExportError)
      end
    end

    context "with very long test name" do
      let(:entries) do
        long_name = "a" * 100
        id = make_identity(test_name: long_name)
        record = flake_record_with(identity: id)
        [
          Wild::Analyzers::TestFlakes::Models::TriageEntry.new(
            flake_record: record,
            severity: :high,
            severity_score: 0.6
          )
        ]
      end

      it "truncates long names" do
        result = exporter.export(entries)
        lines = result.split("\n").reject { |l| l.start_with?("FLAKE") }
        expect(lines.first.length).to be <= 120
      end
    end
  end
end
