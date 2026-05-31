# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Malformed input handling" do
  let(:claude_adapter) { Wild::Telemetry::Pipeline::Ingestion::ClaudeCodeAdapter.new }
  let(:mcp_adapter) { Wild::Telemetry::Pipeline::Ingestion::McpLogAdapter.new }
  let(:generic_adapter) { Wild::Telemetry::Pipeline::Ingestion::GenericAdapter.new }

  describe "ClaudeCodeAdapter" do
    it "raises IngestionError for nil" do
      expect { claude_adapter.parse(nil) }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for empty string" do
      expect { claude_adapter.parse("") }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for whitespace only" do
      expect { claude_adapter.parse("   ") }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "skips lines that are valid JSON but not objects" do
      input = "42\n#{JSON.generate({ "type" => "human", "message" => "hi" })}"
      result = claude_adapter.parse(input)
      expect(result.first.turns.size).to eq(1)
    end

    it "skips truncated JSON lines" do
      input = "{\"type\": \"human\", \"mess\n#{JSON.generate({ "type" => "human", "message" => "hi" })}"
      result = claude_adapter.parse(input)
      expect(result.first.turns.size).to eq(1)
    end

    it "produces transcript with zero turns if all lines skip" do
      input = "42\n\"string\"\nnull"
      result = claude_adapter.parse(input)
      expect(result.first.turns).to be_empty
    end
  end

  describe "McpLogAdapter" do
    it "raises IngestionError for nil" do
      expect { mcp_adapter.parse(nil) }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for empty string" do
      expect { mcp_adapter.parse("") }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for non-JSON" do
      expect { mcp_adapter.parse("not json") }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for JSON object instead of array" do
      expect { mcp_adapter.parse('{"key": "value"}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "handles empty array gracefully" do
      result = mcp_adapter.parse("[]")
      expect(result.first.turns).to be_empty
    end

    it "skips non-Hash entries in the array" do
      data = JSON.generate([nil, 42, "string", { "jsonrpc" => "2.0", "method" => "tools/call",
                                                 "params" => { "name" => "foo" }, "id" => 1 },
                            { "jsonrpc" => "2.0", "result" => {}, "id" => 1 }])
      result = mcp_adapter.parse(data)
      expect(result.first.turns).not_to be_empty
    end

    it "handles truncated JSON" do
      expect { mcp_adapter.parse('[{"method": "tools') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end
  end

  describe "GenericAdapter" do
    it "raises IngestionError for nil" do
      expect { generic_adapter.parse(nil) }.to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for non-JSON string" do
      expect { generic_adapter.parse("just plain text") }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for JSON without turns/messages/array structure" do
      expect { generic_adapter.parse('{"count": 10}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for JSON with turns key but non-array value" do
      expect { generic_adapter.parse('{"turns": "not an array"}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "skips non-Hash entries in turns array" do
      data = JSON.generate({ "turns" => [nil, 42, { "role" => "user", "content" => "hi" }] })
      result = generic_adapter.parse(data)
      expect(result.first.turns.size).to eq(1)
    end

    it "handles completely empty turns array" do
      data = JSON.generate({ "turns" => [] })
      result = generic_adapter.parse(data)
      expect(result.first.turns).to be_empty
    end
  end

  describe "Redactor edge cases" do
    let(:redactor) { Wild::Telemetry::Pipeline::Privacy::Redactor.new }

    it "handles nil content gracefully in redact_content" do
      expect(redactor.redact_content(nil)).to eq(nil.to_s)
    end

    it "handles content with only whitespace" do
      expect(redactor.redact_content("   ")).to eq("   ")
    end

    it "handles very long content" do
      long = "x" * 50_000
      expect { redactor.redact_content(long) }.not_to raise_error
    end

    it "handles content with unicode characters" do
      content = "Email: user@example.com — café résumé"
      result = redactor.redact_content(content)
      expect(result).not_to include("user@example.com")
      expect(result).to include("café")
    end
  end

  describe "ContentFilter edge cases" do
    let(:filter) { Wild::Telemetry::Pipeline::Privacy::ContentFilter.new }

    it "handles nil gracefully" do
      expect(filter.sensitive?(nil)).to be(false)
    end

    it "handles very long clean content" do
      long = "The quick brown fox jumped over the lazy dog. " * 1000
      expect { filter.sensitive?(long) }.not_to raise_error
    end

    it "handles content with embedded null bytes" do
      expect { filter.sensitive?("hello\x00world") }.not_to raise_error
    end
  end
end

# rubocop:enable RSpec/DescribeClass
