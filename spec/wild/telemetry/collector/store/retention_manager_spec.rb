# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/ContextWording

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Wild::Telemetry::Collector::Store::RetentionManager do
  let(:tmpdir) { Dir.mktmpdir("retention_manager_spec") }
  let(:store_path) { File.join(tmpdir, "events.jsonl") }
  let(:store) { Wild::Telemetry::Collector::Store::JsonLinesStore.new(path: store_path) }

  # Timestamps are computed relative to now so the fixtures never age past the
  # 90-day retention window (a hardcoded 2026-03-19 "recent" fixture expired on
  # 2026-06-17 and turned 6 examples red). old_envelope sits 120 days back,
  # well outside the window; new_envelope sits 1 day back, well inside it.
  let(:old_received_at) { (Time.now.utc - (120 * 86_400)).iso8601(3) }
  let(:new_received_at) { (Time.now.utc - 86_400).iso8601(3) }

  let(:old_envelope) do
    Wild::Telemetry::Collector::Schema::EventEnvelope.new(
      event_type: "action.completed",
      timestamp: old_received_at,
      caller_id: "test",
      action: "old_action",
      outcome: "success",
      received_at: old_received_at
    )
  end

  let(:new_envelope) do
    Wild::Telemetry::Collector::Schema::EventEnvelope.new(
      event_type: "action.completed",
      timestamp: new_received_at,
      caller_id: "test",
      action: "new_action",
      outcome: "success",
      received_at: new_received_at
    )
  end

  after { FileUtils.remove_entry(tmpdir) }

  describe "#purge_expired" do
    context "with a retention window of 90 days" do
      let(:manager) { described_class.new(store: store, retention_days: 90) }

      before do
        store.append(old_envelope)
        store.append(new_envelope)
      end

      it "removes events older than the retention window" do
        manager.purge_expired
        expect(store.count).to eq(1)
      end

      it "keeps events within the retention window" do
        manager.purge_expired
        remaining = store.recent.first
        expect(remaining.action).to eq("new_action")
      end

      it "returns the count of removed events" do
        expect(manager.purge_expired).to eq(1)
      end
    end

    context "when all events are within the retention window" do
      let(:manager) { described_class.new(store: store, retention_days: 90) }

      before { store.append(new_envelope) }

      it "returns 0" do
        expect(manager.purge_expired).to eq(0)
      end
    end

    context "for a non-JsonLinesStore" do
      let(:memory_store) { Wild::Telemetry::Collector::Store::MemoryStore.new }
      let(:manager) { described_class.new(store: memory_store, retention_days: 90) }

      it "returns 0 without raising" do
        expect(manager.purge_expired).to eq(0)
      end
    end

    context "when the file does not exist" do
      let(:manager) { described_class.new(store: store, retention_days: 90) }

      it "returns 0" do
        expect(manager.purge_expired).to eq(0)
      end
    end

    context "with a very short retention window (1 day)" do
      let(:manager) { described_class.new(store: store, retention_days: 1) }
      # Use a dynamic timestamp to ensure freshness regardless of test run time
      let(:fresh_envelope) do
        Wild::Telemetry::Collector::Schema::EventEnvelope.new(
          event_type: "action.completed",
          timestamp: Time.now.utc.iso8601(3),
          caller_id: "test",
          action: "fresh_action",
          outcome: "success",
          received_at: Time.now.utc.iso8601(3)
        )
      end

      before do
        store.append(old_envelope)
        store.append(fresh_envelope)
      end

      it "removes events older than one day" do
        manager.purge_expired
        expect(store.count).to eq(1)
      end
    end
  end

  describe "#purge_oversized" do
    context "when max_size_bytes is nil" do
      let(:manager) { described_class.new(store: store, max_size_bytes: nil) }

      before { store.append(new_envelope) }

      it "returns 0" do
        expect(manager.purge_oversized).to eq(0)
      end
    end

    context "for a non-JsonLinesStore" do
      let(:memory_store) { Wild::Telemetry::Collector::Store::MemoryStore.new }
      let(:manager) { described_class.new(store: memory_store, max_size_bytes: 1) }

      it "returns 0 without raising" do
        expect(manager.purge_oversized).to eq(0)
      end
    end

    context "when store is within the size limit" do
      let(:manager) { described_class.new(store: store, max_size_bytes: 1_000_000) }

      before { store.append(new_envelope) }

      it "returns 0" do
        expect(manager.purge_oversized).to eq(0)
      end
    end

    context "when store exceeds the size limit" do
      let(:manager) { described_class.new(store: store, max_size_bytes: 1) }

      before do
        store.append(old_envelope)
        store.append(new_envelope)
      end

      it "removes oldest events until within the limit" do
        manager.purge_oversized
        expect(store.count).to eq(0)
      end

      it "returns the count of removed events" do
        expect(manager.purge_oversized).to be > 0
      end

      it "does not retain the oldest events after purging" do
        manager.purge_oversized
        actions = store.recent.map(&:action)
        expect(actions).not_to include("old_action")
      end
    end
  end

  describe "#purge_all" do
    context "with both expired and oversized conditions" do
      let(:manager) { described_class.new(store: store, retention_days: 90, max_size_bytes: nil) }

      before do
        store.append(old_envelope)
        store.append(new_envelope)
      end

      it "runs both purges and returns the total removed count" do
        total = manager.purge_all
        expect(total).to eq(1)
      end

      it "removes expired events" do
        manager.purge_all
        expect(store.count).to eq(1)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/ContextWording
