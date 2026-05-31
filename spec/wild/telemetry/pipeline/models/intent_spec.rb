# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Models::Intent do
  subject(:intent) do
    described_class.new(description: "Check database", confidence: 0.8, source_turn_index: 2)
  end

  describe "#initialize" do
    it "stores description, confidence, and source_turn_index" do
      expect(intent.description).to eq("Check database")
      expect(intent.confidence).to eq(0.8)
      expect(intent.source_turn_index).to eq(2)
    end

    it "coerces confidence to float" do
      i = described_class.new(description: "test", confidence: 1, source_turn_index: 0)
      expect(i.confidence).to be_a(Float)
    end

    it "accepts 0.0 confidence" do
      i = described_class.new(description: "test", confidence: 0.0, source_turn_index: 0)
      expect(i.confidence).to eq(0.0)
    end

    it "accepts 1.0 confidence" do
      i = described_class.new(description: "test", confidence: 1.0, source_turn_index: 0)
      expect(i.confidence).to eq(1.0)
    end

    it "raises ArgumentError for empty description" do
      expect { described_class.new(description: "", confidence: 0.5, source_turn_index: 0) }
        .to raise_error(ArgumentError, /description/)
    end

    it "raises ArgumentError for non-string description" do
      expect { described_class.new(description: nil, confidence: 0.5, source_turn_index: 0) }
        .to raise_error(ArgumentError, /description/)
    end

    it "raises ArgumentError for confidence above 1.0" do
      expect { described_class.new(description: "test", confidence: 1.1, source_turn_index: 0) }
        .to raise_error(ArgumentError, /confidence/)
    end

    it "raises ArgumentError for negative confidence" do
      expect { described_class.new(description: "test", confidence: -0.1, source_turn_index: 0) }
        .to raise_error(ArgumentError, /confidence/)
    end

    it "raises ArgumentError for negative source_turn_index" do
      expect { described_class.new(description: "test", confidence: 0.5, source_turn_index: -1) }
        .to raise_error(ArgumentError, /source_turn_index/)
    end

    it "raises ArgumentError for non-integer source_turn_index" do
      expect { described_class.new(description: "test", confidence: 0.5, source_turn_index: 1.5) }
        .to raise_error(ArgumentError, /source_turn_index/)
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      h = intent.to_h
      expect(h[:description]).to eq("Check database")
      expect(h[:confidence]).to eq(0.8)
      expect(h[:source_turn_index]).to eq(2)
    end
  end
end
