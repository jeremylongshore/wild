# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Grant do
  describe "#initialize" do
    it "creates a grant with caller and capabilities" do
      grant = described_class.new(caller_id: "agent:test", capabilities: %i[read write])
      expect(grant.caller_id).to eq("agent:test")
      expect(grant.capabilities).to eq(%i[read write])
    end

    it "freezes the object" do
      grant = described_class.new(caller_id: "agent:test", capabilities: [:read])
      expect(grant).to be_frozen
    end
  end

  describe "#wildcard?" do
    it "returns true for wildcard caller" do
      grant = described_class.new(caller_id: "*", capabilities: [:read])
      expect(grant).to be_wildcard
    end

    it "returns false for specific caller" do
      grant = described_class.new(caller_id: "agent:test", capabilities: [:read])
      expect(grant).not_to be_wildcard
    end
  end

  describe "#matches_caller?" do
    it "matches exact caller identity" do
      grant = described_class.new(caller_id: "agent:test", capabilities: [:read])
      expect(grant).to be_matches_caller("agent:test")
    end

    it "does not match different caller" do
      grant = described_class.new(caller_id: "agent:test", capabilities: [:read])
      expect(grant).not_to be_matches_caller("agent:other")
    end

    it "wildcard matches any caller" do
      grant = described_class.new(caller_id: "*", capabilities: [:read])
      expect(grant).to be_matches_caller("anyone")
    end
  end

  describe "#grants_capability?" do
    let(:grant) { described_class.new(caller_id: "agent:test", capabilities: %i[read write]) }

    it "returns true for granted capability" do
      expect(grant).to be_grants_capability(:read)
    end

    it "returns false for ungranted capability" do
      expect(grant).not_to be_grants_capability(:delete)
    end
  end
end
