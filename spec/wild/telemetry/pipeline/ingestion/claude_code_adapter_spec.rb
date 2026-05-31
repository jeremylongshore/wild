# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter do
  subject(:adapter) { described_class.new }

  let(:jsonl) { claude_code_jsonl }

  describe "#parse" do
    it "returns an array of Transcript objects" do
      result = adapter.parse(jsonl)
      expect(result).to be_an(Array)
      expect(result).to all(be_a(Wild::Telemetry::Pipeline::Models::Transcript))
    end

    it "returns a single transcript" do
      expect(adapter.parse(jsonl).size).to eq(1)
    end

    it "sets source_type to :claude_code" do
      expect(adapter.parse(jsonl).first.source_type).to eq(:claude_code)
    end

    it "uses provided source_id" do
      result = adapter.parse(jsonl, source_id: "session-abc")
      expect(result.first.source_id).to eq("session-abc")
    end

    it "generates a source_id when not provided" do
      result = adapter.parse(jsonl)
      expect(result.first.source_id).not_to be_empty
    end

    it "parses human entries as :user turns" do
      result = adapter.parse(jsonl)
      user_turns = result.first.turns.select(&:user_turn?)
      expect(user_turns).not_to be_empty
    end

    it "parses assistant entries as :assistant turns" do
      result = adapter.parse(jsonl)
      assistant_turns = result.first.turns.select(&:assistant_turn?)
      expect(assistant_turns).not_to be_empty
    end

    it "parses tool_use entries as :tool turns" do
      result = adapter.parse(jsonl)
      tool_turns = result.first.turns.select(&:tool_turn?)
      expect(tool_turns).not_to be_empty
    end

    it "parses tool_result entries as :tool turns" do
      result = adapter.parse(jsonl)
      tool_turns = result.first.turns.select(&:tool_turn?)
      expect(tool_turns.size).to eq(2)
    end

    it "preserves timestamps when present" do
      result = adapter.parse(jsonl)
      turns_with_ts = result.first.turns.reject { |t| t.timestamp.nil? }
      expect(turns_with_ts).not_to be_empty
    end

    it "skips lines with unknown type" do
      unknown = JSON.generate({ "type" => "unknown_event", "message" => "ignored" })
      valid = JSON.generate({ "type" => "human", "message" => "hello" })
      result = adapter.parse([unknown, valid].join("\n"))
      expect(result.first.turns.size).to eq(1)
    end

    it "skips malformed JSON lines silently" do
      valid = JSON.generate({ "type" => "human", "message" => "hello" })
      result = adapter.parse("not json\n#{valid}")
      expect(result.first.turns.size).to eq(1)
    end

    it "raises IngestionError for nil input" do
      expect { adapter.parse(nil) }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for empty string" do
      expect { adapter.parse("") }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for whitespace-only input" do
      expect { adapter.parse("   ") }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "includes tool name in metadata for tool_use entries" do
      result = adapter.parse(jsonl)
      tool_use_turn = result.first.turns.find do |t|
        t.tool_turn? && t.metadata[:tool_name] == "inspect_connection"
      end
      expect(tool_use_turn).not_to be_nil
    end

    it "formats tool_use content with tool name and input" do
      result = adapter.parse(jsonl)
      tool_turn = result.first.turns.find { |t| t.tool_turn? && t.metadata[:tool_name] }
      expect(tool_turn.content).to include("inspect_connection")
    end
  end
end
