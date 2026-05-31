# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::Gap do
  subject(:gap) { build_gap }

  describe "initialization" do
    it "coerces type to symbol" do
      g = build_gap(type: "denial")
      expect(g.type).to eq(:denial)
    end

    it "coerces action to string" do
      g = build_gap(action: :read_file)
      expect(g.action).to eq("read_file")
    end

    it "coerces severity to float" do
      g = build_gap(severity: 1)
      expect(g.severity).to be_a(Float)
    end

    it "accepts all valid types" do
      Wild::Telemetry::Analysis::Models::Gap::VALID_TYPES.each do |type|
        expect { build_gap(type: type) }.not_to raise_error
      end
    end

    it "raises ValidationError for unknown type" do
      expect { build_gap(type: :unknown) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "raises ValidationError when severity is below 0" do
      expect { build_gap(severity: -0.1) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "raises ValidationError when severity exceeds 1" do
      expect { build_gap(severity: 1.1) }.to raise_error(Wild::Telemetry::Analysis::ValidationError)
    end

    it "accepts severity of exactly 0.0" do
      expect { build_gap(severity: 0.0) }.not_to raise_error
    end

    it "accepts severity of exactly 1.0" do
      expect { build_gap(severity: 1.0) }.not_to raise_error
    end

    it "allows nil recommendation" do
      g = build_gap(recommendation: nil)
      expect(g.recommendation).to be_nil
    end
  end

  describe "#to_h" do
    it "includes all fields" do
      h = gap.to_h
      expect(h.keys).to include(:type, :action, :severity, :evidence, :description, :recommendation)
    end
  end

  describe "Comparable / sorting" do
    it "sorts higher severity first" do
      low = build_gap(severity: 0.2)
      high = build_gap(severity: 0.8)
      expect([low, high].sort).to eq([high, low])
    end

    it "returns -1 when current gap has higher severity" do
      g1 = build_gap(severity: 0.9)
      g2 = build_gap(severity: 0.5)
      expect(g1 <=> g2).to eq(-1)
    end
  end
end
