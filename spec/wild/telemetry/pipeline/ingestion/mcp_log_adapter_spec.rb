# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter do
  subject(:adapter) { described_class.new }

  let(:mcp_json) { mcp_log_json }

  describe "#parse" do
    it "returns an array of Transcript objects" do
      result = adapter.parse(mcp_json)
      expect(result).to be_an(Array)
      expect(result).to all(be_a(Wild::Telemetry::Pipeline::Models::Transcript))
    end

    it "returns a single transcript" do
      expect(adapter.parse(mcp_json).size).to eq(1)
    end

    it "sets source_type to :mcp_log" do
      expect(adapter.parse(mcp_json).first.source_type).to eq(:mcp_log)
    end

    it "uses provided source_id" do
      result = adapter.parse(mcp_json, source_id: "mcp-session-1")
      expect(result.first.source_id).to eq("mcp-session-1")
    end

    it "creates a turn for each request" do
      result = adapter.parse(mcp_json)
      user_turns = result.first.turns.select(&:user_turn?)
      expect(user_turns).not_to be_empty
    end

    it "creates a tool turn for each response" do
      result = adapter.parse(mcp_json)
      tool_turns = result.first.turns.select(&:tool_turn?)
      expect(tool_turns).not_to be_empty
    end

    it "includes tool name in request turn content" do
      result = adapter.parse(mcp_json)
      request_turn = result.first.turns.find(&:user_turn?)
      expect(request_turn.content).to include("inspect_routes")
    end

    it "includes result text in response turn content" do
      result = adapter.parse(mcp_json)
      response_turn = result.first.turns.find(&:tool_turn?)
      expect(response_turn.content).to include("Found 42 routes")
    end

    it "handles error responses" do
      messages = [
        { "jsonrpc" => "2.0", "method" => "tools/call",
          "params" => { "name" => "bad_tool", "arguments" => {} }, "id" => 9 },
        { "jsonrpc" => "2.0", "error" => { "code" => -32_601, "message" => "Method not found" }, "id" => 9 }
      ]
      result = adapter.parse(JSON.generate(messages))
      error_turn = result.first.turns.find { |t| t.metadata[:mcp_error] }
      expect(error_turn).not_to be_nil
      expect(error_turn.content).to include("mcp:error")
    end

    it "skips non-Hash entries silently" do
      messages = ["not a hash", { "jsonrpc" => "2.0", "method" => "tools/call",
                                  "params" => { "name" => "foo" }, "id" => 1 },
                  { "jsonrpc" => "2.0", "result" => { "content" => [] }, "id" => 1 }]
      result = adapter.parse(JSON.generate(messages))
      expect(result).not_to be_empty
    end

    it "raises IngestionError for nil input" do
      expect { adapter.parse(nil) }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for invalid JSON" do
      expect { adapter.parse("{broken json") }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for non-array JSON" do
      expect { adapter.parse('{"key": "value"}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "handles non-tools/call methods" do
      messages = [
        { "jsonrpc" => "2.0", "method" => "resources/list", "params" => {}, "id" => 5 },
        { "jsonrpc" => "2.0", "result" => { "resources" => [] }, "id" => 5 }
      ]
      result = adapter.parse(JSON.generate(messages))
      expect(result.first.turns).not_to be_empty
    end
  end
end
