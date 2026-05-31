# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Models::RootCause do
  subject(:cause) do
    described_class.new(
      category: :timing_dependent,
      confidence: 0.75,
      evidence: ["High duration variance"],
      description: "Test is timing sensitive"
    )
  end

  describe "#initialize" do
    it "stores all attributes" do
      expect(cause.category).to eq(:timing_dependent)
      expect(cause.confidence).to eq(0.75)
      expect(cause.evidence).to eq(["High duration variance"])
      expect(cause.description).to eq("Test is timing sensitive")
    end

    it "accepts all valid categories" do
      described_class::CATEGORIES.each do |cat|
        expect { described_class.new(category: cat, confidence: 0.5) }.not_to raise_error
      end
    end

    it "raises ArgumentError for invalid category" do
      expect { described_class.new(category: :bogus, confidence: 0.5) }
        .to raise_error(ArgumentError)
    end

    it "raises ArgumentError for confidence > 1" do
      expect { described_class.new(category: :unknown, confidence: 1.5) }
        .to raise_error(ArgumentError)
    end

    it "raises ArgumentError for negative confidence" do
      expect { described_class.new(category: :unknown, confidence: -0.1) }
        .to raise_error(ArgumentError)
    end
  end

  describe "#high_confidence?" do
    it "returns true when confidence >= 0.7" do
      expect(cause.high_confidence?).to be(true)
    end

    it "returns false when confidence < 0.7" do
      low = described_class.new(category: :unknown, confidence: 0.5)
      expect(low.high_confidence?).to be(false)
    end
  end

  describe "#medium_confidence?" do
    it "returns true for confidence in [0.4, 0.7)" do
      med = described_class.new(category: :unknown, confidence: 0.5)
      expect(med.medium_confidence?).to be(true)
    end
  end

  describe "#low_confidence?" do
    it "returns true for confidence < 0.4" do
      low = described_class.new(category: :unknown, confidence: 0.3)
      expect(low.low_confidence?).to be(true)
    end
  end

  describe "#to_h" do
    it "includes all fields" do
      h = cause.to_h
      expect(h[:category]).to eq(:timing_dependent)
      expect(h[:confidence]).to eq(0.75)
      expect(h[:evidence]).to eq(["High duration variance"])
    end
  end
end
