# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Ingestion::ExportParser do
  subject(:parser) { described_class.new }

  describe "#parse_string" do
    it "returns a hash with header and records" do
      result = parser.parse_string(valid_jsonl)
      expect(result).to include(:header, :records)
    end

    it "parses the header as ExportHeader" do
      result = parser.parse_string(valid_jsonl)
      expect(result[:header]).to be_a(Wild::Telemetry::Analysis::Models::ExportHeader)
    end

    it "groups records by record_type symbol" do
      result = parser.parse_string(valid_jsonl)
      expect(result[:records]).to be_a(Hash)
      expect(result[:records][:event]).not_to be_nil
    end

    it "raises ParseError for invalid JSON" do
      bad_jsonl = "{\"export_type\":\"session_telemetry\",\"schema_version\":\"1.0\",\"source_id\":\"x\"}\n{not json}"
      expect { parser.parse_string(bad_jsonl) }.to raise_error(Wild::Telemetry::Analysis::ParseError)
    end

    it "raises ParseError for empty content" do
      expect { parser.parse_string("") }.to raise_error(Wild::Telemetry::Analysis::ParseError, /empty/)
    end

    it "raises SchemaError when header is invalid" do
      bad_header = JSON.generate({ "export_type" => "wrong", "schema_version" => "1.0" })
      expect { parser.parse_string(bad_header) }.to raise_error(Wild::Telemetry::Analysis::SchemaError)
    end

    it "ignores blank lines" do
      jsonl_with_blanks = valid_jsonl.gsub("\n", "\n\n")
      expect { parser.parse_string(jsonl_with_blanks) }.not_to raise_error
    end

    it "parses multiple record types" do
      result = parser.parse_string(valid_jsonl)
      expect(result[:records].keys).to include(:event, :tool_utilization, :outcome_distribution)
    end
  end

  describe "#parse_file" do
    it "raises ParseError when file does not exist" do
      expect { parser.parse_file("/tmp/nonexistent_wild_gap_miner_test.jsonl") }
        .to raise_error(Wild::Telemetry::Analysis::ParseError, /file not found/)
    end

    it "parses a valid file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.jsonl")
        File.write(path, valid_jsonl)
        result = parser.parse_file(path)
        expect(result[:header]).to be_valid
      end
    end

    it "raises ParseError for empty file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "empty.jsonl")
        File.write(path, "")
        expect { parser.parse_file(path) }.to raise_error(Wild::Telemetry::Analysis::ParseError, /empty/)
      end
    end
  end

  describe "with custom config" do
    it "accepts a config object" do
      config = Wild::Configuration::Telemetry::Analysis.new
      p = described_class.new(config: config)
      expect(p.config).to be(config)
    end
  end
end
