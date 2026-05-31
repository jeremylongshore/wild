# frozen_string_literal: true

require "json"

RSpec.describe Wild::Telemetry::Collector::Export::Exporter do
  subject(:exporter) { described_class.new(store: store) }

  let(:store) { Wild::Telemetry::Collector::Store::MemoryStore.new }
  let(:receiver) { Wild::Telemetry::Collector::Collector::EventReceiver.new(store: store) }

  def ingest(overrides = {})
    receiver.receive(valid_action_completed_event.merge(overrides))
  end

  describe "#export" do
    context "with no events" do
      it "returns only the header line" do
        lines = exporter.export
        expect(lines.size).to eq(1)
      end

      it "produces valid JSON header with zero event count" do
        lines = exporter.export
        header = JSON.parse(lines.first)
        expect(header["export_type"]).to eq("session_telemetry")
        expect(header["record_counts"]["events"]).to eq(0)
      end
    end

    context "with events" do
      before do
        3.times { |i| ingest(action: "action_#{i}", timestamp: "2026-03-19T14:3#{i}:00.000Z") }
      end

      it "returns header plus event lines" do
        lines = exporter.export
        expect(lines.size).to eq(4)
      end

      it "produces valid JSON Lines format" do
        lines = exporter.export
        lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
      end

      it "includes event records with correct record_type" do
        lines = exporter.export
        event_records = lines[1..].map { |l| JSON.parse(l) }
        expect(event_records).to all(include("record_type" => "event"))
      end

      it "includes correct event count in header" do
        lines = exporter.export
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(3)
      end
    end

    context "with event_type filter" do
      before do
        ingest(event_type: "action.completed", action: "retry")
        receiver.receive(valid_gate_evaluated_event)
      end

      it "filters by event_type" do
        lines = exporter.export(event_type: "gate.evaluated")
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(1)
        event = JSON.parse(lines[1])
        expect(event["event_type"]).to eq("gate.evaluated")
      end
    end

    context "with time range filter" do
      before do
        ingest(timestamp: "2026-03-18T10:00:00.000Z", action: "old")
        ingest(timestamp: "2026-03-19T10:00:00.000Z", action: "recent")
        ingest(timestamp: "2026-03-20T10:00:00.000Z", action: "future")
      end

      it "filters by since" do
        lines = exporter.export(since: "2026-03-19T00:00:00.000Z")
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(2)
      end

      it "filters by before" do
        lines = exporter.export(before: "2026-03-19T12:00:00.000Z")
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(2)
      end

      it "filters by combined since and before" do
        lines = exporter.export(since: "2026-03-19T00:00:00.000Z", before: "2026-03-19T12:00:00.000Z")
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(1)
      end
    end

    context "with caller_id filter" do
      before do
        ingest(caller_id: "ops-team", action: "retry")
        ingest(caller_id: "dev-team", action: "inspect")
      end

      it "filters by caller_id" do
        lines = exporter.export(caller_id: "ops-team")
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(1)
        event = JSON.parse(lines[1])
        expect(event["caller_id"]).to eq("ops-team")
      end
    end

    context "with combined filters" do
      before do
        ingest(caller_id: "ops", action: "retry", timestamp: "2026-03-19T10:00:00.000Z")
        ingest(caller_id: "dev", action: "inspect", timestamp: "2026-03-19T11:00:00.000Z")
        ingest(caller_id: "ops", action: "discard", timestamp: "2026-03-18T10:00:00.000Z")
      end

      it "applies all filters together" do
        lines = exporter.export(
          caller_id: "ops",
          since: "2026-03-19T00:00:00.000Z",
          event_type: "action.completed"
        )
        header = JSON.parse(lines.first)
        expect(header["record_counts"]["events"]).to eq(1)
        event = JSON.parse(lines[1])
        expect(event["caller_id"]).to eq("ops")
        expect(event["action"]).to eq("retry")
      end
    end

    describe "header correctness" do
      it "includes schema_version in header" do
        header = JSON.parse(exporter.export.first)
        expect(header["schema_version"]).to eq("1.0.0")
      end

      it "includes exported_at timestamp in header" do
        header = JSON.parse(exporter.export.first)
        expect(header["exported_at"]).to match(/\A\d{4}-\d{2}-\d{2}T/)
      end

      it "includes time_range in header" do
        header = JSON.parse(exporter.export(since: "2026-03-01T00:00:00Z", before: "2026-03-31T00:00:00Z").first)
        expect(header["time_range"]["start"]).to eq("2026-03-01T00:00:00Z")
        expect(header["time_range"]["end"]).to eq("2026-03-31T00:00:00Z")
      end
    end

    describe "JSON Lines format" do
      before { 2.times { |i| ingest(action: "act_#{i}") } }

      it "produces one JSON object per line" do
        lines = exporter.export
        expect(lines.size).to eq(3)
        lines.each do |line|
          parsed = JSON.parse(line)
          expect(parsed).to be_a(Hash)
        end
      end

      it "first line is always the header" do
        header = JSON.parse(exporter.export.first)
        expect(header).to have_key("export_type")
        expect(header).to have_key("record_counts")
      end
    end
  end
end
