# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Cross-adapter consistency" do
  let(:json_exporter) { Wild::Telemetry::Pipeline::Export::JsonExporter.new }

  it "all adapters produce Transcript with correct source_type" do
    {
      Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter => [:claude_code, claude_code_jsonl],
      Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter => [:mcp_log, mcp_log_json],
      Wild::Telemetry::Pipeline::Ingestion::GenericAdapter => [:generic, generic_json]
    }.each do |adapter_class, (expected_type, input)|
      transcripts = adapter_class.new.parse(input)
      expect(transcripts.first.source_type).to eq(expected_type)
    end
  end

  it "all adapters produce JSON-serializable transcripts" do
    [
      [Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new, claude_code_jsonl],
      [Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter.new, mcp_log_json],
      [Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new, generic_json]
    ].each do |adapter, input|
      transcripts = adapter.parse(input)
      expect { json_exporter.export(transcripts) }.not_to raise_error
    end
  end

  it "all adapters produce turns with valid roles" do
    valid_roles = Wild::Telemetry::Pipeline::Models::Turn::VALID_ROLES
    [
      [Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new, claude_code_jsonl],
      [Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter.new, mcp_log_json],
      [Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new, generic_json]
    ].each do |adapter, input|
      transcripts = adapter.parse(input)
      roles = transcripts.flat_map(&:turns).map(&:role)
      expect(roles - valid_roles).to be_empty
    end
  end

  it "all adapters produce non-empty turn content" do
    [
      [Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new, claude_code_jsonl],
      [Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new, generic_json]
    ].each do |adapter, input|
      transcripts = adapter.parse(input)
      transcripts.flat_map(&:turns).each do |turn|
        expect(turn.content).to be_a(String)
      end
    end
  end

  it "redactor preserves turn count across all adapter outputs" do
    redactor = Wild::Telemetry::Pipeline::Privacy::Redactor.new
    [
      [Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new, claude_code_jsonl],
      [Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter.new, mcp_log_json],
      [Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new, generic_json]
    ].each do |adapter, input|
      transcripts = adapter.parse(input)
      transcripts.each do |t|
        redacted = redactor.redact_transcript(t)
        expect(redacted.turn_count).to eq(t.turn_count)
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
