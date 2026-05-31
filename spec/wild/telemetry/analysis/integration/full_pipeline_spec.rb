# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, Layout/LineLength

RSpec.describe "Full pipeline integration" do
  let(:jsonl_content) do
    lines = [
      {
        "export_type" => "session_telemetry",
        "schema_version" => "1.0",
        "source_id" => "integration-test",
        "exported_at" => "2025-01-15T10:00:00Z",
        "time_range" => { "start" => "2025-01-14T00:00:00Z", "end" => "2025-01-15T00:00:00Z" },
        "record_counts" => {}
      },
      # Events
      { "record_type" => "event", "event_type" => "tool_call", "timestamp" => "2025-01-15T10:00:00Z",
        "caller_id" => "caller-1", "action" => "read_file", "outcome" => "success", "duration_ms" => 50 },
      { "record_type" => "event", "event_type" => "tool_call", "timestamp" => "2025-01-15T10:00:01Z",
        "caller_id" => "caller-1", "action" => "write_file", "outcome" => "denied", "duration_ms" => 10 },
      # Tool utilization - high failure
      { "record_type" => "tool_utilization", "action" => "exec_command",
        "invocation_count" => 50, "unique_callers" => 3, "success_rate" => 0.2, "avg_duration_ms" => 300.0 },
      { "record_type" => "tool_utilization", "action" => "read_file",
        "invocation_count" => 100, "unique_callers" => 5, "success_rate" => 0.95, "avg_duration_ms" => 50.0 },
      { "record_type" => "tool_utilization", "action" => "write_file",
        "invocation_count" => 2, "unique_callers" => 1, "success_rate" => 0.5, "avg_duration_ms" => 80.0 },
      # Outcome distributions - high denial
      { "record_type" => "outcome_distribution", "action" => "write_file",
        "total_count" => 10,
        "outcomes" => { "success" => 0.5, "denied" => 0.5 } },
      { "record_type" => "outcome_distribution", "action" => "read_file",
        "total_count" => 100,
        "outcomes" => { "success" => 0.95, "denied" => 0.05 } },
      # Latency stats - slow action
      { "record_type" => "latency_stats", "action" => "exec_command",
        "p50_ms" => 200.0, "p95_ms" => 900.0, "p99_ms" => 1200.0,
        "min_ms" => 50.0, "max_ms" => 2000.0, "avg_ms" => 250.0, "sample_count" => 50 },
      # Session summary - low coverage
      { "record_type" => "session_summary", "caller_id" => "caller-1",
        "event_count" => 5, "distinct_actions" => ["read_file"],
        "outcome_breakdown" => { "success" => 4, "denied" => 1 }, "total_duration_ms" => 500 },
      # Pattern - failure cascade
      { "record_type" => "pattern", "pattern_type" => "failure_cascade",
        "sequence" => %w[exec_command exec_command exec_command],
        "occurrence_count" => 8, "unique_callers" => 2 }
    ]
    lines.map { |l| JSON.generate(l) }.join("\n")
  end

  it "processes a JSONL string and returns a GapReport" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report).to be_a(Wild::Telemetry::Analysis::Models::GapReport)
  end

  it "detects denial gaps" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps_of_type(:denial)).not_to be_empty
  end

  it "detects failure gaps" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps_of_type(:failure)).not_to be_empty
  end

  it "detects latency gaps" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps_of_type(:latency)).not_to be_empty
  end

  it "detects pattern gaps" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps_of_type(:pattern)).not_to be_empty
  end

  it "exports to JSON without errors" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    exporter = Wild::Telemetry::Analysis::Export::JsonExporter.new
    expect { JSON.parse(exporter.export(report)) }.not_to raise_error
  end

  it "exports to Markdown without errors" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    exporter = Wild::Telemetry::Analysis::Export::MarkdownExporter.new
    md = exporter.export(report)
    expect(md).to include("# Gap Analysis Report")
  end

  it "uses the convenience Wild::Telemetry::Analysis.analyze method via file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "integration.jsonl")
      File.write(path, jsonl_content)
      report = Wild::Telemetry::Analysis.analyze(path)
      expect(report).to be_a(Wild::Telemetry::Analysis::Models::GapReport)
      expect(report.gaps).not_to be_empty
    end
  end

  it "gap severities are all within [0.0, 1.0]" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps.map(&:severity)).to all(be_between(0.0, 1.0))
  end

  it "all gaps have recommendations" do
    parser = Wild::Telemetry::Analysis::Ingestion::ExportParser.new
    parsed = parser.parse_string(jsonl_content)
    report = Wild::Telemetry::Analysis::Report::Builder.new(records: parsed[:records].merge(header: parsed[:header])).build
    expect(report.gaps.map(&:recommendation)).to all(be_a(String).and(satisfy { |s| !s.empty? }))
  end
end

# rubocop:enable RSpec/DescribeClass, Layout/LineLength
