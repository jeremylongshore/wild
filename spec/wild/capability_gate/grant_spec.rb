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

    # F4 reconciliation (wild-lkp): CapabilityGate is exact-match BY DESIGN — it
    # does NOT wildcard-expand capability names. A grant for :read confers only
    # :read, never :read_something; wildcard expansion is the Permission
    # analyzer's job. This pins the design decision so a future change can't
    # silently smuggle glob semantics into the runtime gate.
    it "does NOT treat a '*' capability as a wildcard (exact-symbol match only)" do
      wild_grant = described_class.new(caller_id: "agent:test", capabilities: ["*"])
      expect(wild_grant).to be_grants_capability(:*)
      expect(wild_grant).not_to be_grants_capability(:read)
      expect(wild_grant).not_to be_grants_capability(:anything_else)
    end

    it "does not prefix-match capability names" do
      grant = described_class.new(caller_id: "agent:test", capabilities: %i[admin.jobs.view])
      expect(grant).to be_grants_capability(:"admin.jobs.view")
      expect(grant).not_to be_grants_capability(:"admin.jobs.retry")
    end
  end
end
