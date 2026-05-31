# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Models::Capability do
  subject(:cap) { described_class.new(name: "admin.jobs.view") }

  describe "#initialize" do
    it "requires a name" do
      expect(cap.name).to eq("admin.jobs.view")
    end

    it "defaults description to empty string" do
      expect(cap.description).to eq("")
    end

    it "defaults risk_level to low" do
      expect(cap.risk_level).to eq("low")
    end

    it "defaults prerequisites to frozen empty array" do
      expect(cap.prerequisites).to eq([])
      expect(cap.prerequisites).to be_frozen
    end

    it "defaults tags to frozen empty array" do
      expect(cap.tags).to eq([])
      expect(cap.tags).to be_frozen
    end

    it "stores full attributes when provided" do
      c = described_class.new(
        name: "admin.jobs.retry",
        description: "Retry jobs",
        risk_level: "medium",
        prerequisites: ["admin.jobs.view"],
        tags: ["admin"]
      )
      expect(c.prerequisites).to eq(["admin.jobs.view"])
      expect(c.tags).to eq(["admin"])
    end
  end

  describe "equality" do
    it "is equal to another capability with the same name" do
      other = described_class.new(name: "admin.jobs.view", risk_level: "high")
      expect(cap).to eq(other)
    end

    it "is not equal to a capability with a different name" do
      other = described_class.new(name: "admin.jobs.retry")
      expect(cap).not_to eq(other)
    end

    it "is not equal to a non-Capability" do
      expect(cap).not_to eq("admin.jobs.view")
    end
  end

  describe "#hash" do
    it "returns same hash for same name" do
      other = described_class.new(name: "admin.jobs.view")
      expect(cap.hash).to eq(other.hash)
    end
  end

  describe "#to_s" do
    it "returns the name" do
      expect(cap.to_s).to eq("admin.jobs.view")
    end
  end
end
