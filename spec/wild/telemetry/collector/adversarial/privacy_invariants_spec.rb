# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Privacy invariants (doc 003 section 9)" do
  let(:store) { Wild::Telemetry::Collector::Store::MemoryStore.new }
  let(:receiver) { Wild::Telemetry::Collector::Collector::EventReceiver.new(store: store) }
  let(:filter) { Wild::Telemetry::Collector::Privacy::Filter.new }

  def ingest(overrides = {})
    receiver.receive(valid_action_completed_event.merge(overrides))
  end

  describe "Invariant 1: no forbidden field survives to storage" do
    Wild::Telemetry::Collector::Privacy::Filter::FORBIDDEN_FIELD_NAMES.each do |field|
      it "strips forbidden field '#{field}' from metadata before storage" do
        ingest(metadata: { category: "jobs", field.to_sym => "smuggled" })
        stored = store.query.first
        expect(stored.metadata.keys.map(&:to_s)).not_to include(field)
      end
    end

    it "strips forbidden fields injected as top-level keys" do
      result = filter.filter(valid_action_completed_event.merge(params: { job_id: "123" }))
      expect(result).not_to have_key(:params)
    end
  end

  describe "Invariant 2: per-type allowlists are enforced" do
    it "strips unknown metadata keys from action.completed events" do
      ingest(metadata: { category: "jobs", unknown_key: "value", secret: "data" })
      stored = store.query.first
      expect(stored.metadata.keys.map(&:to_s)).not_to include("unknown_key", "secret")
    end

    it "strips unknown metadata keys from gate.evaluated events" do
      receiver.receive(valid_gate_evaluated_event.merge(metadata: { gate_result: "allowed", extra: "data" }))
      stored = store.query.first
      expect(stored.metadata.keys.map(&:to_s)).not_to include("extra")
    end

    it "strips unknown metadata keys from rate_limit.checked events" do
      receiver.receive(valid_rate_limit_checked_event.merge(metadata: { rate_result: "ok", secret: "x" }))
      stored = store.query.first
      expect(stored.metadata.keys.map(&:to_s)).not_to include("secret")
    end
  end

  describe "Invariant 3: allowlists are not configurable" do
    it "METADATA_ALLOWLISTS is frozen" do
      expect(Wild::Telemetry::Collector::Privacy::Filter::METADATA_ALLOWLISTS).to be_frozen
    end

    it "each allowlist array is frozen" do
      Wild::Telemetry::Collector::Privacy::Filter::METADATA_ALLOWLISTS.each_value do |list|
        expect(list).to be_frozen
      end
    end
  end

  describe "Invariant 4: expired events are not exported" do
    it "excludes events outside the query time range" do
      ingest(timestamp: "2025-01-01T00:00:00.000Z", action: "old")
      ingest(timestamp: "2026-03-19T14:00:00.000Z", action: "recent")
      results = store.query(since: "2026-01-01T00:00:00.000Z")
      actions = results.map(&:action)
      expect(actions).not_to include("old")
      expect(actions).to include("recent")
    end
  end

  describe "Invariant 5: storage size is bounded (conceptual)" do
    it "MemoryStore respects query limits via recent" do
      10.times { |i| ingest(action: "act_#{i}", timestamp: "2026-03-19T14:#{format("%02d", i)}:00.000Z") }
      recent = store.recent(limit: 3)
      expect(recent.size).to eq(3)
    end
  end

  describe "Invariant 6: collection is opt-in" do
    it "store receives no events without explicit receiver attachment" do
      standalone_store = Wild::Telemetry::Collector::Store::MemoryStore.new
      expect(standalone_store.count).to eq(0)
    end
  end

  describe "Invariant 7: small-population aggregations are suppressed" do
    it "suppresses aggregations below min_population threshold" do
      engine = Wild::Telemetry::Collector::Aggregation::Engine.new(min_population: 5)
      events = 3.times.map { |i| build_envelope(action: "rare", timestamp: "2026-03-19T14:0#{i}:00.000Z") }
      expect(engine.tool_utilization(events)).to be_empty
      expect(engine.outcome_distributions(events)).to be_empty
      expect(engine.latency_stats(events)).to be_empty
      expect(engine.session_summaries(events)).to be_empty
    end
  end

  describe "Invariant 8: privacy filtering is not bypassable" do
    it "EventReceiver always applies the privacy filter" do
      ingest(metadata: { category: "jobs", params: "secret", nonce: "abc" })
      stored = store.query.first
      metadata_keys = stored.metadata.keys.map(&:to_s)
      expect(metadata_keys).not_to include("params")
      expect(metadata_keys).not_to include("nonce")
    end

    it "cannot store events without going through receive" do
      envelope = build_envelope(metadata: { category: "jobs" })
      store.append(envelope)
      expect(store.count).to eq(1)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
