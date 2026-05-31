# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Recommendations::Engine do
  subject(:engine) { described_class.new }

  describe "#enrich" do
    context "when gap already has a recommendation" do
      let(:gap) { build_gap(recommendation: "Existing recommendation") }

      it "preserves the existing recommendation" do
        enriched = engine.enrich([gap])
        expect(enriched.first.recommendation).to eq("Existing recommendation")
      end
    end

    context "when gap has no recommendation" do
      let(:gap) { build_gap(recommendation: nil) }

      it "fills in a recommendation" do
        enriched = engine.enrich([gap])
        expect(enriched.first.recommendation).not_to be_nil
      end

      it "uses the gap type in the recommendation" do
        enriched = engine.enrich([gap])
        expect(enriched.first.recommendation).not_to be_empty
      end
    end

    it "handles each gap type" do
      Wild::Telemetry::Analysis::Models::Gap::VALID_TYPES.each do |type|
        gap = build_gap(type: type, recommendation: nil)
        enriched = engine.enrich([gap])
        expect(enriched.first.recommendation).not_to be_nil
      end
    end

    it "returns the same number of gaps" do
      gaps = [build_gap(recommendation: nil), build_gap(recommendation: "set")]
      expect(engine.enrich(gaps).length).to eq(2)
    end

    it "returns empty array for empty input" do
      expect(engine.enrich([])).to eq([])
    end

    it "preserves all other gap fields" do
      gap = build_gap(type: :failure, action: "my_action", severity: 0.7, recommendation: nil)
      enriched = engine.enrich([gap]).first
      expect(enriched.action).to eq("my_action")
      expect(enriched.severity).to eq(0.7)
    end
  end
end
