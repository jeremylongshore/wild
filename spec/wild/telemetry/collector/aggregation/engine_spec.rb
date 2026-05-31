# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Collector::Aggregation::Engine do
  subject(:engine) { described_class.new(min_population: 3) }

  let(:base_time) { "2026-03-19T14:00:00.000Z" }

  def make_events(count, overrides = {})
    count.times.map do |i|
      build_envelope({
        timestamp: "2026-03-19T14:#{format("%02d", i)}:00.000Z",
        duration_ms: 10.0 + i
      }.merge(overrides))
    end
  end

  describe "#session_summaries" do
    it "groups events by caller_id and time window" do
      events = make_events(5, caller_id: "ops")
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries.size).to eq(1)
      expect(summaries.first[:caller_id]).to eq("ops")
      expect(summaries.first[:event_count]).to eq(5)
    end

    it "separates events into different windows" do
      events = [
        *make_events(3, caller_id: "ops"),
        build_envelope(caller_id: "ops", timestamp: "2026-03-19T15:30:00.000Z", duration_ms: 20),
        build_envelope(caller_id: "ops", timestamp: "2026-03-19T15:31:00.000Z", duration_ms: 21),
        build_envelope(caller_id: "ops", timestamp: "2026-03-19T15:32:00.000Z", duration_ms: 22)
      ]
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries.size).to eq(2)
    end

    it "separates events by caller_id" do
      events = [
        *make_events(3, caller_id: "ops"),
        *make_events(4, caller_id: "dev")
      ]
      summaries = engine.session_summaries(events, window_seconds: 3600)
      callers = summaries.pluck(:caller_id)
      expect(callers).to contain_exactly("ops", "dev")
    end

    it "computes outcome breakdown" do
      events = [
        *make_events(3, outcome: "success"),
        *make_events(3, outcome: "error")
      ]
      summaries = engine.session_summaries(events, window_seconds: 3600)
      breakdown = summaries.first[:outcome_breakdown]
      expect(breakdown["success"]).to eq(3)
      expect(breakdown["error"]).to eq(3)
    end

    it "computes distinct actions" do
      events = [
        *make_events(3, action: "retry_job"),
        *make_events(3, action: "inspect_job")
      ]
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries.first[:distinct_actions]).to contain_exactly("inspect_job", "retry_job")
    end

    it "computes total_duration_ms" do
      events = make_events(3) # durations: 10.0, 11.0, 12.0
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries.first[:total_duration_ms]).to eq(33.0)
    end

    it "suppresses summaries below min_population" do
      events = make_events(2)
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries).to be_empty
    end

    it "includes window_start and window_end as ISO 8601" do
      events = make_events(3)
      summaries = engine.session_summaries(events, window_seconds: 3600)
      expect(summaries.first[:window_start]).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(summaries.first[:window_end]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end
  end

  describe "#tool_utilization" do
    it "groups by action and computes invocation count" do
      events = make_events(5, action: "retry_job")
      records = engine.tool_utilization(events)
      expect(records.size).to eq(1)
      expect(records.first[:action]).to eq("retry_job")
      expect(records.first[:invocation_count]).to eq(5)
    end

    it "computes success rate" do
      events = [
        *make_events(3, action: "retry", outcome: "success"),
        *make_events(2, action: "retry", outcome: "error")
      ]
      records = engine.tool_utilization(events)
      expect(records.first[:success_rate]).to eq(0.6)
    end

    it "computes avg_duration_ms" do
      events = make_events(3, action: "retry") # 10.0, 11.0, 12.0
      records = engine.tool_utilization(events)
      expect(records.first[:avg_duration_ms]).to eq(11.0)
    end

    it "counts unique callers" do
      events = [
        *make_events(3, action: "retry", caller_id: "ops"),
        *make_events(3, action: "retry", caller_id: "dev")
      ]
      records = engine.tool_utilization(events)
      expect(records.first[:unique_callers]).to eq(2)
    end

    it "suppresses records below min_population" do
      events = make_events(2, action: "rare_action")
      records = engine.tool_utilization(events)
      expect(records).to be_empty
    end

    it "handles nil duration_ms by returning nil avg" do
      events = make_events(3, action: "retry", duration_ms: nil)
      records = engine.tool_utilization(events)
      expect(records.first[:avg_duration_ms]).to be_nil
    end
  end

  describe "#outcome_distributions" do
    it "computes per-action outcome percentages" do
      events = [
        *make_events(3, action: "retry", outcome: "success"),
        *make_events(2, action: "retry", outcome: "denied")
      ]
      records = engine.outcome_distributions(events)
      expect(records.first[:total_count]).to eq(5)
      expect(records.first[:outcomes]["success"][:count]).to eq(3)
      expect(records.first[:outcomes]["success"][:percentage]).to eq(0.6)
    end

    it "includes all outcome types present" do
      events = [
        build_envelope(action: "retry", outcome: "success"),
        build_envelope(action: "retry", outcome: "denied"),
        build_envelope(action: "retry", outcome: "error")
      ]
      records = engine.outcome_distributions(events)
      outcomes = records.first[:outcomes]
      expect(outcomes.keys).to contain_exactly("success", "denied", "error")
    end

    it "suppresses below min_population" do
      events = make_events(2, action: "rare")
      records = engine.outcome_distributions(events)
      expect(records).to be_empty
    end
  end

  describe "#latency_stats" do
    it "computes min, max, avg, and sample_count" do
      durations = [10, 20, 30, 40, 50]
      events = durations.map { |d| build_envelope(action: "retry", duration_ms: d.to_f) }
      stats = engine.latency_stats(events).first
      expect(stats[:sample_count]).to eq(5)
      expect(stats[:min]).to eq(10.0)
      expect(stats[:max]).to eq(50.0)
      expect(stats[:avg]).to eq(30.0)
    end

    it "computes p50, p95, and p99 percentiles" do
      durations = [10, 20, 30, 40, 50]
      events = durations.map { |d| build_envelope(action: "retry", duration_ms: d.to_f) }
      stats = engine.latency_stats(events).first
      expect(stats[:p50]).to be_a(Numeric)
      expect(stats[:p95]).to be_a(Numeric)
      expect(stats[:p99]).to be_a(Numeric)
    end

    it "excludes events with nil duration_ms" do
      events = [
        *make_events(3, action: "retry"),
        build_envelope(action: "retry", duration_ms: nil)
      ]
      records = engine.latency_stats(events)
      expect(records.first[:sample_count]).to eq(3)
    end

    it "suppresses below min_population" do
      events = make_events(2, action: "retry")
      records = engine.latency_stats(events)
      expect(records).to be_empty
    end

    it "handles single-element array" do
      engine_low = described_class.new(min_population: 1)
      events = [build_envelope(action: "retry", duration_ms: 42.0)]
      records = engine_low.latency_stats(events)
      expect(records.first[:p50]).to eq(42.0)
    end

    it "returns empty for events with all nil durations" do
      events = make_events(5, action: "retry", duration_ms: nil)
      records = engine.latency_stats(events)
      expect(records).to be_empty
    end
  end
end
