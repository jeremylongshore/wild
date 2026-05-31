# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

RSpec.describe "Full pipeline integration" do
  let(:normalizer) { Wild::Telemetry::Pipeline::Normalization::TurnNormalizer.new }
  let(:intent_detector) { Wild::Telemetry::Pipeline::Normalization::IntentDetector.new }
  let(:tool_extractor) { Wild::Telemetry::Pipeline::Normalization::ToolExtractor.new }
  let(:redactor) { Wild::Telemetry::Pipeline::Privacy::Redactor.new }
  let(:json_exporter) { Wild::Telemetry::Pipeline::Export::JsonExporter.new }
  let(:md_exporter) { Wild::Telemetry::Pipeline::Export::MarkdownExporter.new }

  describe "Claude Code session pipeline" do
    let(:jsonl) { claude_code_jsonl }
    let(:adapter) { Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new }

    it "completes ingest -> normalize -> redact -> export without error" do
      transcripts = adapter.parse(jsonl, source_id: "session-001")
      normalized = transcripts.map { |t| normalizer.normalize(t.turns) }
      redacted = normalized.map { |turns| turns.map { |turn| redactor.redact_turn(turn) } }
      expect(redacted).not_to be_empty
    end

    it "produces valid JSON output" do
      transcripts = Wild::Telemetry::Pipeline.process(jsonl, adapter: adapter, source_id: "session-001")
      json = json_exporter.export(transcripts)
      parsed = JSON.parse(json)
      expect(parsed["summary"]["transcript_count"]).to eq(1)
    end

    it "produces non-empty markdown output" do
      transcripts = Wild::Telemetry::Pipeline.process(jsonl, adapter: adapter)
      md = md_exporter.export(transcripts)
      expect(md).to include("# Transcript Export")
      expect(md).to include("### Turns")
    end

    it "detects tool references for tool_use entries" do
      transcripts = Wild::Telemetry::Pipeline.process(jsonl, adapter: adapter)
      all_refs = transcripts.flat_map(&:tool_references)
      expect(all_refs.map(&:name)).to include("inspect_connection")
    end
  end

  describe "MCP log pipeline" do
    let(:json) { mcp_log_json }
    let(:adapter) { Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter.new }

    it "ingests and processes MCP logs" do
      transcripts = Wild::Telemetry::Pipeline.process(json, adapter: adapter, source_id: "mcp-001")
      expect(transcripts).to all(be_a(Wild::Telemetry::Pipeline::Models::Transcript))
    end

    it "produces exportable JSON" do
      transcripts = Wild::Telemetry::Pipeline.process(json, adapter: adapter)
      output = json_exporter.export(transcripts)
      expect { JSON.parse(output) }.not_to raise_error
    end

    it "detects tool references from MCP requests" do
      transcripts = Wild::Telemetry::Pipeline.process(json, adapter: adapter)
      all_refs = transcripts.flat_map(&:tool_references)
      expect(all_refs).not_to be_empty
    end
  end

  describe "Generic conversation pipeline" do
    let(:json) { generic_json }
    let(:adapter) { Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new }

    it "processes generic conversations end to end" do
      transcripts = Wild::Telemetry::Pipeline.process(json, adapter: adapter)
      expect(transcripts).not_to be_empty
    end

    it "strips sensitive content in generic conversations" do
      turns = [
        { "role" => "user", "content" => "My email is secret@corp.com" },
        { "role" => "assistant", "content" => "Got it" }
      ]
      input = JSON.generate({ "turns" => turns })
      transcripts = Wild::Telemetry::Pipeline.process(input, adapter: adapter)
      content_values = transcripts.flat_map(&:turns).map(&:content)
      expect(content_values.join).not_to include("secret@corp.com")
    end
  end

  describe "Batch export" do
    it "exports multiple transcripts as a batch" do
      batch = make_transcript_batch(count: 3)
      json = json_exporter.export_batch(batch)
      parsed = JSON.parse(json)
      expect(parsed["summary"]["transcript_count"]).to eq(3)
    end
  end

  describe "Wild::Telemetry::Pipeline.process convenience method" do
    it "returns Transcript objects" do
      adapter = Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new
      result = Wild::Telemetry::Pipeline.process(generic_json, adapter: adapter)
      expect(result).to all(be_a(Wild::Telemetry::Pipeline::Models::Transcript))
    end

    it "marks transcripts as processed" do
      adapter = Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new
      result = Wild::Telemetry::Pipeline.process(generic_json, adapter: adapter)
      expect(result.first.metadata[:processed]).to be(true)
    end

    it "applies custom config" do
      adapter = Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new
      Wild.configure do |c|
        c.telemetry.pipeline.max_turns_per_transcript = 1
      end
      result = Wild::Telemetry::Pipeline.process(generic_json, adapter: adapter,
                                                               config: Wild.config.telemetry.pipeline)
      expect(result.first.turn_count).to be <= 1
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
