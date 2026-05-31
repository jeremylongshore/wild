# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::LatencyStats do
  subject(:stat) { build_latency_stats }

  describe "attribute readers" do
    it "exposes action" do
      expect(stat.action).to eq("read_file")
    end

    it "reads p50 from p50_ms key" do
      expect(stat.p50).to eq(100.0)
    end

    it "reads p95 from p95_ms key" do
      expect(stat.p95).to eq(300.0)
    end

    it "reads p99 from p99_ms key" do
      expect(stat.p99).to eq(450.0)
    end

    it "reads min from min_ms key" do
      expect(stat.min).to eq(10.0)
    end

    it "reads max from max_ms key" do
      expect(stat.max).to eq(600.0)
    end

    it "reads avg from avg_ms key" do
      expect(stat.avg).to eq(120.0)
    end

    it "exposes sample_count" do
      expect(stat.sample_count).to eq(50)
    end

    it "falls back to bare key if _ms key absent" do
      s = described_class.new("record_type" => "latency_stats", "action" => "x", "p95" => 200.0)
      expect(s.p95).to eq(200.0)
    end
  end

  describe "record_type" do
    it "is latency_stats" do
      expect(stat.record_type).to eq("latency_stats")
    end
  end
end
