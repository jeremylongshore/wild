# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Wild::Telemetry::Collector::Store::StorageMonitor do
  let(:tmpdir) { Dir.mktmpdir("storage_monitor_spec") }
  let(:store_path) { File.join(tmpdir, "events.jsonl") }
  let(:json_store) { Wild::Telemetry::Collector::Store::JsonLinesStore.new(path: store_path) }
  let(:memory_store) { Wild::Telemetry::Collector::Store::MemoryStore.new }

  let(:older_envelope) do
    Wild::Telemetry::Collector::Schema::EventEnvelope.new(
      event_type: "action.completed",
      timestamp: "2026-03-19T10:00:00.000Z",
      caller_id: "test",
      action: "first_action",
      outcome: "success",
      received_at: "2026-03-19T10:00:00.000Z"
    )
  end

  let(:newer_envelope) do
    Wild::Telemetry::Collector::Schema::EventEnvelope.new(
      event_type: "action.completed",
      timestamp: "2026-03-19T10:00:01.000Z",
      caller_id: "test",
      action: "second_action",
      outcome: "success",
      received_at: "2026-03-19T10:00:01.000Z"
    )
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe "#stats" do
    context "with an empty store" do
      let(:monitor) { described_class.new(store: json_store) }

      it "returns zero event_count" do
        expect(monitor.stats[:event_count]).to eq(0)
      end

      it "returns nil for oldest_event" do
        expect(monitor.stats[:oldest_event]).to be_nil
      end

      it "returns nil for newest_event" do
        expect(monitor.stats[:newest_event]).to be_nil
      end
    end

    context "with a JsonLinesStore containing events" do
      let(:monitor) { described_class.new(store: json_store) }

      before do
        json_store.append(older_envelope)
        json_store.append(newer_envelope)
      end

      it "returns the correct event_count" do
        expect(monitor.stats[:event_count]).to eq(2)
      end

      it "returns a positive size_bytes" do
        expect(monitor.stats[:size_bytes]).to be > 0
      end

      it "returns the oldest event received_at" do
        expect(monitor.stats[:oldest_event]).to eq("2026-03-19T10:00:00.000Z")
      end

      it "returns the newest event received_at" do
        expect(monitor.stats[:newest_event]).to eq("2026-03-19T10:00:01.000Z")
      end

      it "returns the store_type as the class name" do
        expect(monitor.stats[:store_type]).to eq("Wild::Telemetry::Collector::Store::JsonLinesStore")
      end
    end

    context "with a MemoryStore" do
      let(:monitor) { described_class.new(store: memory_store) }

      before { memory_store.append(build_envelope) }

      it "returns nil for size_bytes" do
        expect(monitor.stats[:size_bytes]).to be_nil
      end

      it "returns the correct store_type" do
        expect(monitor.stats[:store_type]).to eq("Wild::Telemetry::Collector::Store::MemoryStore")
      end
    end
  end

  describe "#healthy?" do
    context "when the store is functioning normally" do
      let(:monitor) { described_class.new(store: json_store) }

      it "returns true" do
        expect(monitor.healthy?).to be(true)
      end
    end

    context "when the store raises on count" do
      let(:broken_store) do
        store = Wild::Telemetry::Collector::Store::MemoryStore.new
        allow(store).to receive(:count).and_raise(RuntimeError, "disk failure")
        store
      end
      let(:monitor) { described_class.new(store: broken_store) }

      it "returns false" do
        expect(monitor.healthy?).to be(false)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
