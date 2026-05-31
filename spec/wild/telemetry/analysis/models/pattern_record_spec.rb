# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::PatternRecord do
  subject(:pattern) { build_pattern_record }

  describe "attribute readers" do
    it "exposes pattern_type" do
      expect(pattern.pattern_type).to eq("retry_loop")
    end

    it "exposes sequence" do
      expect(pattern.sequence).to eq(%w[read_file read_file read_file])
    end

    it "exposes occurrence_count" do
      expect(pattern.occurrence_count).to eq(5)
    end

    it "reads callers_affected from unique_callers key" do
      expect(pattern.callers_affected).to eq(2)
    end

    it "falls back to callers_affected key" do
      p = described_class.new(
        "record_type" => "pattern", "pattern_type" => "x",
        "sequence" => [], "occurrence_count" => 1, "callers_affected" => 3
      )
      expect(p.callers_affected).to eq(3)
    end

    it "defaults sequence to empty array" do
      p = build_pattern_record("sequence" => nil)
      expect(p.sequence).to eq([])
    end
  end

  describe "#failure_cascade?" do
    it "returns true for failure_cascade pattern type" do
      p = build_pattern_record("pattern_type" => "failure_cascade")
      expect(p).to be_failure_cascade
    end

    it "returns false for other pattern types" do
      expect(pattern).not_to be_failure_cascade
    end
  end

  describe "record_type" do
    it "is pattern" do
      expect(pattern.record_type).to eq("pattern")
    end
  end
end
