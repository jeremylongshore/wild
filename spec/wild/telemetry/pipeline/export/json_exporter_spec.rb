# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Export::JsonExporter do
  subject(:exporter) { described_class.new }

  let(:transcripts) { [make_transcript, make_transcript(source_id: "test-002")] }

  describe "#export" do
    it "returns a JSON string" do
      result = exporter.export(transcripts)
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
    end

    it "includes metadata section" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed).to have_key("metadata")
    end

    it "includes generated_at in metadata" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed["metadata"]).to have_key("generated_at")
    end

    it "includes version in metadata" do
      parsed = JSON.parse(exporter.export(transcripts))
      # F1 — one gem-level version constant; the old per-gem VERSION was deleted.
      expect(parsed["metadata"]["version"]).to eq(Wild::VERSION)
    end

    it "includes schema_version in metadata" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed["metadata"]["schema_version"]).to eq("1.0")
    end

    it "includes summary section" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed).to have_key("summary")
    end

    it "reports correct transcript_count in summary" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed["summary"]["transcript_count"]).to eq(2)
    end

    it "reports correct total_turns in summary" do
      parsed = JSON.parse(exporter.export(transcripts))
      expected = transcripts.sum(&:turn_count)
      expect(parsed["summary"]["total_turns"]).to eq(expected)
    end

    it "includes transcripts array" do
      parsed = JSON.parse(exporter.export(transcripts))
      expect(parsed["transcripts"].size).to eq(2)
    end

    it "exports empty array cleanly" do
      parsed = JSON.parse(exporter.export([]))
      expect(parsed["summary"]["transcript_count"]).to eq(0)
      expect(parsed["transcripts"]).to eq([])
    end

    it "merges provided metadata into output" do
      parsed = JSON.parse(exporter.export(transcripts, metadata: { source: "test_run" }))
      expect(parsed["metadata"]["source"]).to eq("test_run")
    end

    it "raises ExportError for non-Array input" do
      expect { exporter.export("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::ExportError)
    end
  end

  describe "#export_batch" do
    it "exports a TranscriptBatch" do
      batch = make_transcript_batch(count: 2)
      result = exporter.export_batch(batch)
      parsed = JSON.parse(result)
      expect(parsed["summary"]["transcript_count"]).to eq(2)
    end

    it "raises ExportError for non-Batch input" do
      expect { exporter.export_batch("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::ExportError)
    end
  end
end
