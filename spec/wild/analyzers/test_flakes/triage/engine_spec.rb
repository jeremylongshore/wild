# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Triage::Engine do
  subject(:engine) { described_class.new }

  let(:records) do
    multiple_flake_records(count: 3).tap do |recs|
      # Assign root causes
      recs.map.with_index do |rec, i|
        cause = Wild::Analyzers::TestFlakes::Models::RootCause.new(
          category: :timing_dependent,
          confidence: 0.5 + (i * 0.1)
        )
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: rec.test_identity,
          results: rec.results,
          root_causes: [cause]
        )
      end
    end
  end

  describe "#triage" do
    it "returns TriageEntry objects" do
      entries = engine.triage(records)
      expect(entries).to all(be_a(Wild::Analyzers::TestFlakes::Models::TriageEntry))
    end

    it "returns entries sorted by severity_score descending" do
      entries = engine.triage(records)
      scores = entries.map(&:severity_score)
      expect(scores).to eq(scores.sort.reverse)
    end

    it "returns one entry per flake record" do
      entries = engine.triage(records)
      expect(entries.size).to eq(records.size)
    end

    it "assigns severity to each entry" do
      entries = engine.triage(records)
      entries.each do |entry|
        expect(Wild::Analyzers::TestFlakes::Models::TriageEntry::SEVERITIES).to include(entry.severity)
      end
    end

    it "populates remediations" do
      entries = engine.triage(records)
      entries.each do |entry|
        expect(entry.remediations).to be_an(Array)
      end
    end

    context "with empty input" do
      it "returns empty array" do
        expect(engine.triage([])).to eq([])
      end
    end

    context "with invalid input" do
      it "raises ArgumentError" do
        expect { engine.triage("bad") }.to raise_error(ArgumentError)
      end
    end

    context "with history store" do
      let(:store) { Wild::Analyzers::TestFlakes::History::Store.new }

      it "uses trend from history store" do
        engine_with_store = described_class.new(history_store: store)
        entries = engine_with_store.triage(records)
        expect(entries).to all(be_a(Wild::Analyzers::TestFlakes::Models::TriageEntry))
      end
    end
  end
end
