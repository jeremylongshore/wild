# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Capability do
  describe "#initialize" do
    it "creates a capability with valid attributes" do
      cap = described_class.new(
        name: "basic_introspection",
        description: "Read-only schema inspection",
        risk_level: "standard"
      )

      expect(cap.name).to eq(:basic_introspection)
      expect(cap.description).to eq("Read-only schema inspection")
      expect(cap.risk_level).to eq(:standard)
      expect(cap.prerequisites).to eq([])
    end

    it "accepts symbol inputs" do
      cap = described_class.new(name: :admin_tools, description: "", risk_level: :critical)

      expect(cap.name).to eq(:admin_tools)
      expect(cap.risk_level).to eq(:critical)
    end

    it "accepts prerequisites" do
      prereq = Wild::CapabilityGate::Prerequisite.new(type: :file_exists, path: "/tmp/test")
      cap = described_class.new(
        name: :guarded,
        description: "Has prerequisites",
        risk_level: :elevated,
        prerequisites: [prereq]
      )

      expect(cap.prerequisites).to eq([prereq])
      expect(cap).to be_prerequisites
    end

    it "freezes the object after creation" do
      cap = described_class.new(name: :frozen, description: "", risk_level: :standard)
      expect(cap).to be_frozen
    end

    it "freezes prerequisites array" do
      cap = described_class.new(name: :frozen, description: "", risk_level: :standard, prerequisites: [])
      expect(cap.prerequisites).to be_frozen
    end

    it "rejects empty name" do
      expect { described_class.new(name: "", description: "", risk_level: :standard) }
        .to raise_error(ArgumentError, /must not be empty/)
    end

    it "rejects unknown risk level" do
      expect { described_class.new(name: :bad, description: "", risk_level: :extreme) }
        .to raise_error(ArgumentError, /unknown risk_level/)
    end
  end

  describe "risk level predicates" do
    it "#standard? returns true for standard risk" do
      cap = described_class.new(name: :s, description: "", risk_level: :standard)
      expect(cap).to be_standard
      expect(cap).not_to be_elevated
      expect(cap).not_to be_critical
    end

    it "#elevated? returns true for elevated risk" do
      cap = described_class.new(name: :e, description: "", risk_level: :elevated)
      expect(cap).not_to be_standard
      expect(cap).to be_elevated
      expect(cap).not_to be_critical
    end

    it "#critical? returns true for critical risk" do
      cap = described_class.new(name: :c, description: "", risk_level: :critical)
      expect(cap).not_to be_standard
      expect(cap).not_to be_elevated
      expect(cap).to be_critical
    end
  end

  describe "#prerequisites?" do
    it "returns false when no prerequisites" do
      cap = described_class.new(name: :bare, description: "", risk_level: :standard)
      expect(cap).not_to be_prerequisites
    end

    it "returns true when prerequisites exist" do
      prereq = Wild::CapabilityGate::Prerequisite.new(type: :file_exists, path: "/tmp/test")
      cap = described_class.new(name: :guarded, description: "", risk_level: :elevated, prerequisites: [prereq])
      expect(cap).to be_prerequisites
    end
  end
end
