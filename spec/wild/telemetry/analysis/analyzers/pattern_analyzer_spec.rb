# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Analyzers::PatternAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when pattern occurs enough times" do
      let(:pattern) { build_pattern_record("occurrence_count" => 5) }
      let(:records) { { pattern: [pattern] } }

      it "returns a pattern gap" do
        gaps = analyzer.analyze(records)
        expect(gaps.length).to eq(1)
      end

      it "sets gap type to :pattern" do
        gap = analyzer.analyze(records).first
        expect(gap.type).to eq(:pattern)
      end

      it "includes pattern_type in evidence" do
        gap = analyzer.analyze(records).first
        expect(gap.evidence[:pattern_type]).to eq("retry_loop")
      end

      it "uses the sequence as the action label" do
        gap = analyzer.analyze(records).first
        expect(gap.action).to include("read_file")
      end
    end

    context "when occurrence_count is below minimum" do
      let(:pattern) { build_pattern_record("occurrence_count" => 1) }
      let(:records) { { pattern: [pattern] } }

      it "returns no gaps" do
        expect(analyzer.analyze(records)).to be_empty
      end
    end

    context "with failure_cascade pattern" do
      let(:pattern) { build_pattern_record("pattern_type" => "failure_cascade", "occurrence_count" => 5) }
      let(:records) { { pattern: [pattern] } }

      it "returns a gap with higher base severity" do
        gap = analyzer.analyze(records).first
        expect(gap.severity).to be > 0.5
      end

      it "includes cascade-specific recommendation" do
        gap = analyzer.analyze(records).first
        expect(gap.recommendation).to include("cascade")
      end
    end

    context "with no pattern records" do
      it "returns empty array" do
        expect(analyzer.analyze({})).to eq([])
      end
    end

    context "with custom pattern_min_occurrences" do
      it "uses configured minimum" do
        Wild.configure { |c| c.telemetry.analysis.pattern_min_occurrences = 10 }
        analyzer = described_class.new
        pattern = build_pattern_record("occurrence_count" => 5)
        gaps = analyzer.analyze({ pattern: [pattern] })
        expect(gaps).to be_empty
      end
    end
  end
end
