# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Collector::Aggregation::PatternDetector do
  subject(:detector) { described_class.new(min_sequence_length: 2, min_occurrence_count: 3, session_gap_seconds: 300) }

  def make_session(actions, caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z", outcome: "success")
    actions.each_with_index.map do |action, i|
      ts = Time.parse(base_time).utc + (i * 10)
      build_envelope(action: action, caller_id: caller_id, timestamp: ts.utc.iso8601(3), outcome: outcome)
    end
  end

  describe "#detect_sequences" do
    it "detects repeated action sequences" do
      events = [
        *make_session(%w[inspect retry inspect], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry inspect], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z"),
        *make_session(%w[inspect retry inspect], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      sequences = patterns.pluck(:sequence)
      expect(sequences).to include(%w[inspect retry])
    end

    it "returns occurrence_count and unique_callers" do
      events = [
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "dev", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "admin", base_time: "2026-03-19T14:00:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      pattern = patterns.find { |p| p[:sequence] == %w[inspect retry] }
      expect(pattern[:occurrence_count]).to be >= 3
      expect(pattern[:unique_callers]).to eq(3)
    end

    it "sets pattern_type to sequential" do
      events = [
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      expect(patterns).to all(include(pattern_type: "sequential"))
    end

    it "suppresses sequences below min_occurrence_count" do
      events = [
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      pattern = patterns.find { |p| p[:sequence] == %w[inspect retry] }
      expect(pattern).to be_nil
    end

    it "ranks patterns by frequency (most frequent first)" do
      events = [
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z"),
        *make_session(%w[inspect retry], caller_id: "ops", base_time: "2026-03-19T17:00:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      expect(patterns.first[:occurrence_count]).to be >= patterns.last[:occurrence_count]
    end

    it "groups events into sessions by time gap" do
      events = [
        build_envelope(action: "inspect", caller_id: "ops", timestamp: "2026-03-19T14:00:00.000Z"),
        build_envelope(action: "retry", caller_id: "ops", timestamp: "2026-03-19T14:01:00.000Z"),
        build_envelope(action: "inspect", caller_id: "ops", timestamp: "2026-03-19T15:00:00.000Z"),
        build_envelope(action: "retry", caller_id: "ops", timestamp: "2026-03-19T15:01:00.000Z"),
        build_envelope(action: "inspect", caller_id: "ops", timestamp: "2026-03-19T16:00:00.000Z"),
        build_envelope(action: "retry", caller_id: "ops", timestamp: "2026-03-19T16:01:00.000Z")
      ]
      patterns = detector.detect_sequences(events)
      pattern = patterns.find { |p| p[:sequence] == %w[inspect retry] }
      expect(pattern).not_to be_nil
      expect(pattern[:occurrence_count]).to be >= 3
    end

    it "returns empty for empty events" do
      expect(detector.detect_sequences([])).to be_empty
    end

    it "returns empty for single event" do
      events = [build_envelope(action: "inspect")]
      expect(detector.detect_sequences(events)).to be_empty
    end
  end

  describe "#detect_failure_cascades" do
    it "detects failure action sequences" do
      events = [
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z", outcome: "error"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z", outcome: "error"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z", outcome: "error")
      ]
      patterns = detector.detect_failure_cascades(events)
      pattern = patterns.find { |p| p[:sequence] == %w[retry discard] }
      expect(pattern).not_to be_nil
    end

    it "sets pattern_type to failure_cascade" do
      events = [
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z", outcome: "denied"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z", outcome: "denied"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z", outcome: "denied")
      ]
      patterns = detector.detect_failure_cascades(events)
      expect(patterns).to all(include(pattern_type: "failure_cascade"))
    end

    it "excludes success events from failure cascade detection" do
      events = [
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T14:00:00.000Z", outcome: "success"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T15:00:00.000Z", outcome: "success"),
        *make_session(%w[retry discard], caller_id: "ops", base_time: "2026-03-19T16:00:00.000Z", outcome: "success")
      ]
      patterns = detector.detect_failure_cascades(events)
      expect(patterns).to be_empty
    end

    it "returns empty for empty events" do
      expect(detector.detect_failure_cascades([])).to be_empty
    end
  end
end
