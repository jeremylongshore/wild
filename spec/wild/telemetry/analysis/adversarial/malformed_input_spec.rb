# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Adversarial: malformed input handling" do
  let(:parser) { Wild::Telemetry::Analysis::Ingestion::ExportParser.new }

  describe "parse_string edge cases" do
    it "raises ParseError for pure whitespace" do
      expect { parser.parse_string("   \n   \n") }.to raise_error(Wild::Telemetry::Analysis::ParseError)
    end

    it "raises ParseError when header JSON is truncated" do
      expect { parser.parse_string('{"export_type":') }.to raise_error(Wild::Telemetry::Analysis::ParseError)
    end

    it "raises ParseError when a data line has invalid JSON" do
      header = JSON.generate(Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures::HEADER_DATA)
      expect { parser.parse_string("#{header}\n{bad json}") }.to raise_error(Wild::Telemetry::Analysis::ParseError)
    end

    it "raises SchemaError when header missing source_id" do
      bad_header = JSON.generate("export_type" => "session_telemetry", "schema_version" => "1.0")
      expect { parser.parse_string(bad_header) }.to raise_error(Wild::Telemetry::Analysis::SchemaError)
    end

    it "raises SchemaError when export_type does not match" do
      bad_header = JSON.generate("export_type" => "wrong", "schema_version" => "1.0", "source_id" => "x")
      expect { parser.parse_string(bad_header) }.to raise_error(Wild::Telemetry::Analysis::SchemaError)
    end

    it "handles records with missing optional fields gracefully" do
      header_line = JSON.generate(Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures::HEADER_DATA)
      minimal_event = JSON.generate("record_type" => "event")
      result = parser.parse_string("#{header_line}\n#{minimal_event}")
      expect(result[:records][:event].first).to be_a(Wild::Telemetry::Analysis::Models::EventRecord)
    end

    it "handles records with null field values" do
      header_line = JSON.generate(Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures::HEADER_DATA)
      null_record = JSON.generate(
        "record_type" => "tool_utilization", "action" => nil,
        "invocation_count" => nil, "success_rate" => nil
      )
      expect { parser.parse_string("#{header_line}\n#{null_record}") }.not_to raise_error
    end

    it "handles very large JSONL content" do
      header_line = JSON.generate(Wild::Telemetry::Analysis::TestSupport::TelemetryFixtures::HEADER_DATA)
      events = Array.new(500) do |i|
        JSON.generate(
          "record_type" => "event", "event_type" => "tool_call",
          "timestamp" => "2025-01-15T10:00:00Z", "caller_id" => "caller-#{i}",
          "action" => "action_#{i % 10}", "outcome" => "success", "duration_ms" => i
        )
      end
      content = ([header_line] + events).join("\n")
      result = parser.parse_string(content)
      expect(result[:records][:event].length).to eq(500)
    end
  end

  describe "Gap model adversarial inputs" do
    it "rejects unknown gap types" do
      expect { build_gap(type: :totally_unknown) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "rejects severity of -0.001" do
      expect { build_gap(severity: -0.001) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "rejects severity of 1.001" do
      expect { build_gap(severity: 1.001) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "coerces integer severity to float" do
      gap = build_gap(severity: 1)
      expect(gap.severity).to be_a(Float)
    end
  end

  # The old gem's Configuration did per-setter validation + freeze!. Wild's
  # typed Struct dropped both (no-freeze design); the 8 validation/freeze specs
  # are deleted rather than rewritten — F3 (no vanity tests of absent behavior).

  describe "Analyzer adversarial inputs" do
    let(:analyzer) { Wild::Telemetry::Analysis::Analyzers::DenialAnalyzer.new }

    it "handles records hash with nil values gracefully" do
      records = { outcome_distribution: nil }
      expect { analyzer.analyze(records) }.not_to raise_error
    end

    it "returns empty array for completely empty records" do
      expect(analyzer.analyze({})).to eq([])
    end
  end

  describe "ExportParser file edge cases" do
    it "raises ParseError for nonexistent file" do
      expect { parser.parse_file("/tmp/__wild_gap_miner_no_such_file__.jsonl") }
        .to raise_error(Wild::Telemetry::Analysis::ParseError, /file not found/)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
