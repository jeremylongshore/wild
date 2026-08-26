# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Export::JsonExporter do
  subject(:exporter) { described_class.new }

  let(:entries) { [triage_entry, triage_entry(severity: :medium, score: 0.35)] }

  describe "#export" do
    it "returns a String" do
      result = exporter.export(entries)
      expect(result).to be_a(String)
    end

    it "produces valid JSON" do
      result = exporter.export(entries)
      expect { JSON.parse(result) }.not_to raise_error
    end

    it "includes a metadata section" do
      parsed = JSON.parse(exporter.export(entries))
      expect(parsed).to have_key("metadata")
    end

    it "includes a summary section" do
      parsed = JSON.parse(exporter.export(entries))
      expect(parsed).to have_key("summary")
    end

    it "includes a flakes array" do
      parsed = JSON.parse(exporter.export(entries))
      expect(parsed["flakes"]).to be_an(Array)
      expect(parsed["flakes"].size).to eq(2)
    end

    it "includes correct summary counts" do
      parsed = JSON.parse(exporter.export(entries))
      expect(parsed["summary"]["total"]).to eq(2)
    end

    it "computes avg_flake_rate as the mean of each entry's flake_record.flake_rate" do
      parsed = JSON.parse(exporter.export(entries))
      expected = (entries.sum { |e| e.flake_record.flake_rate } / entries.size).round(4)
      expect(parsed["summary"]["avg_flake_rate"]).to eq(expected)
      # Both fixture entries share the default flake_record_with(flake_rate_numerator: 2, total: 5)
      # shape (2 failures / 5 runs), so the average is pinned to a concrete value, not just
      # re-derived from the same formula the exporter uses.
      expect(parsed["summary"]["avg_flake_rate"]).to eq(0.4)
    end

    it "accepts custom metadata" do
      result = exporter.export(entries, metadata: { "ci_build" => "build-123" })
      parsed = JSON.parse(result)
      expect(parsed["metadata"]["ci_build"]).to eq("build-123")
    end

    context "with empty entries" do
      it "returns valid JSON with zero counts" do
        parsed = JSON.parse(exporter.export([]))
        expect(parsed["summary"]["total"]).to eq(0)
      end
    end

    context "with invalid input" do
      it "raises ExportError" do
        expect { exporter.export("bad") }.to raise_error(Wild::Analyzers::TestFlakes::ExportError)
      end
    end
  end
end
