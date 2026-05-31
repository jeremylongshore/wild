# frozen_string_literal: true

RSpec.describe Wild::Skillops::Health::Aggregator do
  let(:registry)    { populated_registry }
  let(:aggregator)  { registry.health_aggregator }
  let(:tracker)     { registry.health_tracker }

  describe "#summary" do
    it "returns a summary hash with expected keys" do
      summary = aggregator.summary
      expect(summary).to include(:total_skills, :tracked, :untracked, :counts, :stale_count)
    end

    it "reports zero tracked when no health is recorded" do
      expect(aggregator.summary[:tracked]).to eq(0)
      expect(aggregator.summary[:untracked]).to eq(4)
    end

    it "counts by state correctly" do
      tracker.record("introspect.schema", state: :available)
      tracker.record("admin.reindex", state: :degraded)
      summary = aggregator.summary
      expect(summary[:counts][:available]).to eq(1)
      expect(summary[:counts][:degraded]).to eq(1)
    end

    it "counts stale entries" do
      stale_time = Time.now.utc - (25 * 3600)
      tracker.record("introspect.schema", state: :available, checked_at: stale_time)
      expect(aggregator.summary[:stale_count]).to eq(1)
    end
  end

  describe "#untracked_entries" do
    it "returns all entries with no health status" do
      untracked = aggregator.untracked_entries
      expect(untracked.size).to eq(4)
    end

    it "excludes tracked entries" do
      tracker.record("introspect.schema", state: :available)
      expect(aggregator.untracked_entries.size).to eq(3)
    end
  end

  describe "#stale_entries" do
    it "returns entries whose health is stale" do
      stale_time = Time.now.utc - (25 * 3600)
      tracker.record("introspect.schema", state: :available, checked_at: stale_time)
      expect(aggregator.stale_entries.map(&:name)).to include("introspect.schema")
    end

    it "does not include fresh entries" do
      tracker.record("admin.reindex", state: :available, checked_at: Time.now.utc)
      expect(aggregator.stale_entries.map(&:name)).not_to include("admin.reindex")
    end
  end

  describe "#entries_by_state" do
    it "returns entries matching the given state" do
      tracker.record("introspect.schema", state: :available)
      tracker.record("admin.reindex", state: :available)
      tracker.record("telemetry.flush", state: :degraded)
      available = aggregator.entries_by_state(:available)
      expect(available.size).to eq(2)
    end

    it "returns empty array for state with no matches" do
      expect(aggregator.entries_by_state(:unavailable)).to eq([])
    end
  end
end
