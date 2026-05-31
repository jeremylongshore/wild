# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::Telemetry::Collector::Store::MemoryStore do
  subject(:store) { described_class.new }

  let(:envelope_a) { build_envelope(timestamp: "2026-03-19T14:30:00.000Z", event_type: "action.completed") }
  let(:envelope_b) { build_envelope(timestamp: "2026-03-19T14:30:01.000Z", event_type: "gate.evaluated") }
  let(:envelope_c) { build_envelope(timestamp: "2026-03-19T14:30:02.000Z", event_type: "rate_limit.checked") }

  describe "#append and #count" do
    it "appends an envelope and increments count" do
      expect { store.append(envelope_a) }.to change(store, :count).from(0).to(1)
    end

    it "returns the appended envelope" do
      result = store.append(envelope_a)
      expect(result).to eq(envelope_a)
    end
  end

  describe "#recent" do
    before do
      store.append(envelope_a)
      store.append(envelope_b)
      store.append(envelope_c)
    end

    it "returns envelopes in reverse-chronological order" do
      results = store.recent
      expect(results.first).to eq(envelope_c)
      expect(results.last).to eq(envelope_a)
    end

    it "respects the limit parameter" do
      results = store.recent(limit: 2)
      expect(results.size).to eq(2)
      expect(results.first).to eq(envelope_c)
    end

    it "returns all envelopes when limit exceeds count" do
      results = store.recent(limit: 100)
      expect(results.size).to eq(3)
    end
  end

  describe "#find" do
    before { store.append(envelope_a) }

    it "locates an envelope by timestamp and event_type" do
      result = store.find(timestamp: envelope_a.timestamp, event_type: envelope_a.event_type)
      expect(result).to eq(envelope_a)
    end

    it "returns nil for a non-existent timestamp/event_type combination" do
      result = store.find(timestamp: "1970-01-01T00:00:00Z", event_type: "action.completed")
      expect(result).to be_nil
    end

    it "returns nil when event_type does not match" do
      result = store.find(timestamp: envelope_a.timestamp, event_type: "gate.evaluated")
      expect(result).to be_nil
    end
  end

  describe "#count" do
    it "returns 0 for an empty store" do
      expect(store.count).to eq(0)
    end

    it "returns correct count after multiple appends" do
      store.append(envelope_a)
      store.append(envelope_b)
      expect(store.count).to eq(2)
    end
  end

  describe "#query" do
    before do
      store.append(envelope_a)
      store.append(envelope_b)
      store.append(envelope_c)
    end

    context "when filtering by event_type" do
      it "returns only envelopes matching the event_type" do
        results = store.query(event_type: "action.completed")
        expect(results.size).to eq(1)
        expect(results.first.event_type).to eq("action.completed")
      end
    end

    context "when filtering by since" do
      it "excludes envelopes with timestamps before the since boundary" do
        results = store.query(since: "2026-03-19T14:30:01.000Z")
        expect(results.map(&:timestamp)).not_to include("2026-03-19T14:30:00.000Z")
        expect(results.size).to eq(2)
      end
    end

    context "when filtering by before" do
      it "excludes envelopes with timestamps at or after the before boundary" do
        results = store.query(before: "2026-03-19T14:30:02.000Z")
        expect(results.map(&:timestamp)).not_to include("2026-03-19T14:30:02.000Z")
        expect(results.size).to eq(2)
      end
    end

    context "when filtering by both since and before" do
      it "returns only envelopes within the time range" do
        results = store.query(
          since: "2026-03-19T14:30:01.000Z",
          before: "2026-03-19T14:30:02.000Z"
        )
        expect(results.size).to eq(1)
        expect(results.first).to eq(envelope_b)
      end
    end

    context "without filters" do
      it "returns all envelopes" do
        results = store.query
        expect(results.size).to eq(3)
      end
    end
  end

  describe "thread safety" do
    it "handles concurrent appends without data loss" do
      threads = 20.times.map do |i|
        Thread.new do
          store.append(build_envelope(timestamp: "2026-03-19T14:30:#{i.to_s.rjust(2, "0")}.000Z"))
        end
      end
      threads.each(&:join)
      expect(store.count).to eq(20)
    end
  end

  describe "#clear!" do
    before do
      store.append(envelope_a)
      store.append(envelope_b)
    end

    it "removes all envelopes from the store" do
      store.clear!
      expect(store.count).to eq(0)
    end

    it "leaves the store usable after clearing" do
      store.clear!
      store.append(envelope_c)
      expect(store.count).to eq(1)
    end
  end
end
