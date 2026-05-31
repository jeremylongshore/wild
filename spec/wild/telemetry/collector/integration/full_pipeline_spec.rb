# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

require "tmpdir"
require "json"

RSpec.describe "Full pipeline integration" do
  let(:store_dir) { Dir.mktmpdir }
  let(:store_path) { File.join(store_dir, "telemetry.jsonl") }
  let(:store) { Wild::Telemetry::Collector::Store::JsonLinesStore.new(path: store_path) }
  let(:receiver) { Wild::Telemetry::Collector::Collector::EventReceiver.new(store: store) }
  let(:aggregator) { Wild::Telemetry::Collector::Aggregation::Engine.new(min_population: 3) }
  let(:pattern_detector) { Wild::Telemetry::Collector::Aggregation::PatternDetector.new(min_occurrence_count: 2) }
  let(:exporter) do
    Wild::Telemetry::Collector::Export::Exporter.new(
      store: store, aggregator: aggregator, pattern_detector: pattern_detector
    )
  end

  after { FileUtils.rm_rf(store_dir) }

  def ingest(overrides = {})
    receiver.receive(valid_action_completed_event.merge(overrides))
  end

  describe "EventReceiver → store → aggregate → export pipeline" do
    it "ingests, stores, aggregates, and exports events end-to-end" do
      10.times { |i| ingest(action: "retry_job", timestamp: "2026-03-19T14:#{format("%02d", i)}:00.000Z") }
      lines = exporter.export
      header = JSON.parse(lines.first)

      expect(header["record_counts"]["events"]).to eq(10)
      expect(lines.size).to be > 1
    end

    it "processes all three event types" do
      5.times { |i| ingest(timestamp: "2026-03-19T14:0#{i}:00.000Z") }
      5.times do |i|
        receiver.receive(valid_gate_evaluated_event.merge(timestamp: "2026-03-19T14:1#{i}:00.000Z"))
      end
      5.times do |i|
        receiver.receive(valid_rate_limit_checked_event.merge(timestamp: "2026-03-19T14:2#{i}:00.000Z"))
      end

      expect(store.count).to eq(15)
      lines = exporter.export
      events = lines[1..].map { |l| JSON.parse(l) }.select { |r| r["record_type"] == "event" }
      types = events.pluck("event_type").uniq
      expect(types).to contain_exactly("action.completed", "gate.evaluated", "rate_limit.checked")
    end
  end

  describe "volume test" do
    it "handles 200+ events without error" do
      200.times do |i|
        ingest(
          action: "action_#{i % 10}",
          caller_id: "caller_#{i % 5}",
          timestamp: "2026-03-19T#{format("%02d", 10 + (i / 60))}:#{format("%02d", i % 60)}:00.000Z",
          duration_ms: rand(10.0..100.0)
        )
      end

      expect(store.count).to eq(200)
      lines = exporter.export
      header = JSON.parse(lines.first)
      expect(header["record_counts"]["events"]).to eq(200)
    end
  end

  describe "retention integration" do
    it "retains recent events and can query by time range" do
      ingest(timestamp: "2026-03-18T10:00:00.000Z", action: "old")
      ingest(timestamp: "2026-03-19T10:00:00.000Z", action: "recent")

      recent = store.query(since: "2026-03-19T00:00:00.000Z")
      expect(recent.size).to eq(1)
      expect(recent.first.action).to eq("recent")
    end
  end

  describe "error path — invalid events" do
    it "silently rejects events with missing required fields" do
      result = receiver.receive({ event_type: "action.completed" })
      expect(result).to be_nil
      expect(store.count).to eq(0)
    end

    it "silently rejects events with invalid event_type" do
      result = receiver.receive(valid_action_completed_event.merge(event_type: "bad.type"))
      expect(result).to be_nil
    end
  end

  describe "error path — forbidden metadata" do
    it "strips forbidden metadata before storage" do
      ingest(metadata: { category: "jobs", params: "secret", nonce: "abc123" })
      events = store.query
      metadata = events.first.metadata
      expect(metadata).not_to have_key(:params)
      expect(metadata).not_to have_key(:nonce)
      expect(metadata).to have_key(:category)
    end
  end

  describe "export schema contract" do
    before do
      5.times { |i| ingest(action: "retry", timestamp: "2026-03-19T14:0#{i}:00.000Z", duration_ms: 10.0 + i) }
    end

    it "produces valid JSON Lines with header first" do
      lines = exporter.export
      header = JSON.parse(lines.first)
      expect(header).to have_key("export_type")
      expect(header).to have_key("schema_version")
      expect(header).to have_key("exported_at")
      expect(header).to have_key("time_range")
      expect(header).to have_key("record_counts")
    end

    it "includes typed records with record_type field" do
      lines = exporter.export
      records = lines[1..].map { |l| JSON.parse(l) }
      expect(records).to all(have_key("record_type"))
    end

    it "event records match expected schema" do
      lines = exporter.export
      event = lines[1..].map { |l| JSON.parse(l) }.find { |r| r["record_type"] == "event" }
      expect(event).to include("event_type", "timestamp", "caller_id", "action", "outcome")
    end

    it "aggregation records are included when population threshold met" do
      lines = exporter.export
      record_types = lines[1..].map { |l| JSON.parse(l)["record_type"] }.uniq
      expect(record_types).to include("event")
      expect(record_types).to include("tool_utilization")
    end
  end

  describe "JsonLinesStore durability" do
    it "persists events across store reloads" do
      5.times { |i| ingest(action: "retry", timestamp: "2026-03-19T14:0#{i}:00.000Z") }
      new_store = Wild::Telemetry::Collector::Store::JsonLinesStore.new(path: store_path)
      expect(new_store.count).to eq(5)
    end
  end

  describe "privacy filter pipeline verification" do
    it "ensures no raw params reach storage via the full pipeline" do
      receiver.receive(valid_action_completed_event.merge(
                         params: { job_id: "12345" },
                         metadata: { category: "jobs", params: "smuggled" }
                       ))
      events = store.query
      next unless events.any?

      event = events.first
      expect(event.to_h).not_to have_key(:params)
      expect(event.metadata).not_to have_key(:params)
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
