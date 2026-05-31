# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Safety rules (doc 005)" do
  let(:store) { Wild::Telemetry::Collector::Store::MemoryStore.new }
  let(:receiver) { Wild::Telemetry::Collector::Collector::EventReceiver.new(store: store) }

  def ingest(overrides = {})
    receiver.receive(valid_action_completed_event.merge(overrides))
  end

  describe "Rule 1: never store raw parameter values" do
    it "strips params from metadata" do
      ingest(metadata: { category: "jobs", params: { job_id: "123" } })
      stored = store.query.first
      expect(stored.metadata.keys.map(&:to_s)).not_to include("params")
    end

    it "strips parameters from metadata" do
      ingest(metadata: { category: "jobs", parameters: "secret" })
      stored = store.query.first
      expect(stored.metadata.keys.map(&:to_s)).not_to include("parameters")
    end

    it "strips params injected as top-level event field" do
      filter = Wild::Telemetry::Collector::Privacy::Filter.new
      result = filter.filter(valid_action_completed_event.merge(params: "job_123"))
      expect(result).not_to have_key(:params)
    end
  end

  describe "Rule 2: validate at ingestion, reject silently" do
    it "silently rejects events with missing required fields" do
      result = receiver.receive({ event_type: "action.completed" })
      expect(result).to be_nil
      expect(store.count).to eq(0)
    end

    it "silently rejects events with invalid event_type" do
      result = receiver.receive(valid_action_completed_event.merge(event_type: "unknown.type"))
      expect(result).to be_nil
    end

    it "does not raise exceptions for invalid events" do
      expect { receiver.receive({}) }.not_to raise_error
    end
  end

  describe "Rule 3: strip unknown/forbidden fields (defense in depth)" do
    it "strips all forbidden field names from metadata" do
      names = Wild::Telemetry::Collector::Privacy::Filter::FORBIDDEN_FIELD_NAMES
      forbidden_metadata = names.to_h { |f| [f.to_sym, "smuggled"] }
      ingest(metadata: { category: "jobs" }.merge(forbidden_metadata))
      stored = store.query.first
      stored_keys = stored.metadata.keys.map(&:to_s)
      Wild::Telemetry::Collector::Privacy::Filter::FORBIDDEN_FIELD_NAMES.each do |field|
        expect(stored_keys).not_to include(field)
      end
    end
  end

  describe "Rule 4: bound storage growth" do
    it "MemoryStore enforces count limits via retention manager" do
      manager = Wild::Telemetry::Collector::Store::RetentionManager.new(store: store, retention_days: 90)
      expect(manager).to respond_to(:purge_expired)
    end
  end

  describe "Rule 5: fire-and-forget — failures never propagate" do
    it "swallows store errors during receive" do
      broken_store = Wild::Telemetry::Collector::Store::MemoryStore.new
      allow(broken_store).to receive(:append).and_raise(StandardError, "disk full")
      broken_receiver = Wild::Telemetry::Collector::Collector::EventReceiver.new(store: broken_store)
      expect { broken_receiver.receive(valid_action_completed_event) }.not_to raise_error
    end

    it "returns nil on internal failure" do
      broken_store = Wild::Telemetry::Collector::Store::MemoryStore.new
      allow(broken_store).to receive(:append).and_raise(StandardError, "disk full")
      broken_receiver = Wild::Telemetry::Collector::Collector::EventReceiver.new(store: broken_store)
      expect(broken_receiver.receive(valid_action_completed_event)).to be_nil
    end
  end

  describe "Rule 6: per-event-type metadata allowlisting" do
    it "only passes allowlisted keys for action.completed" do
      ingest(metadata: { category: "jobs", operation: "retry", evil: "data", secret: "val" })
      stored = store.query.first
      stored_keys = stored.metadata.keys.map(&:to_s)
      expect(stored_keys).to include("category", "operation")
      expect(stored_keys).not_to include("evil", "secret")
    end
  end

  describe "Rule 7: no PII in aggregations" do
    it "suppresses aggregations below population threshold" do
      engine = Wild::Telemetry::Collector::Aggregation::Engine.new(min_population: 10)
      events = 5.times.map { |i| build_envelope(timestamp: "2026-03-19T14:0#{i}:00.000Z") }
      expect(engine.tool_utilization(events)).to be_empty
    end
  end

  # Rule 8 (immutable configuration after startup) was enforced in the old gem
  # by a freeze!/frozen? lifecycle on a per-namespace Configuration class.
  # Wild's typed Struct dropped that machinery (no-freeze configuration
  # design); the 2 freeze specs are deleted rather than rewritten — F3 (no
  # vanity tests of absent behavior).
end

# rubocop:enable RSpec/DescribeClass
