# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Models::Grant do
  subject(:grant) do
    described_class.new(
      caller_id: "ops-team",
      capabilities: ["admin.jobs.*"],
      context: { "environment" => "production" },
      expires_at: nil
    )
  end

  describe "#initialize" do
    it "stores caller_id" do
      expect(grant.caller_id).to eq("ops-team")
    end

    it "stores frozen capabilities" do
      expect(grant.capabilities).to eq(["admin.jobs.*"])
      expect(grant.capabilities).to be_frozen
    end

    it "stores frozen context" do
      expect(grant.context).to eq("environment" => "production")
      expect(grant.context).to be_frozen
    end

    it "defaults context to empty hash when nil" do
      g = described_class.new(caller_id: "x", capabilities: [], context: nil)
      expect(g.context).to eq({})
    end

    it "stores expires_at" do
      expect(grant.expires_at).to be_nil
    end
  end

  describe "#wildcard_capabilities" do
    it "returns only wildcard patterns" do
      g = described_class.new(
        caller_id: "x",
        capabilities: ["admin.jobs.*", "admin.jobs.view", "admin.*"]
      )
      expect(g.wildcard_capabilities).to eq(["admin.jobs.*", "admin.*"])
    end

    it "returns empty array when no wildcards" do
      g = described_class.new(caller_id: "x", capabilities: ["admin.jobs.view"])
      expect(g.wildcard_capabilities).to be_empty
    end
  end

  describe "#expired?" do
    it "returns false when expires_at is nil" do
      expect(grant.expired?).to be false
    end

    it "returns true for a past date" do
      g = described_class.new(caller_id: "x", capabilities: [], expires_at: "2020-01-01")
      expect(g.expired?).to be true
    end

    it "returns false for a future date" do
      g = described_class.new(caller_id: "x", capabilities: [], expires_at: "2099-01-01")
      expect(g.expired?).to be false
    end
  end

  describe "equality" do
    it "equals another grant with same caller_id and capabilities" do
      other = described_class.new(caller_id: "ops-team", capabilities: ["admin.jobs.*"])
      expect(grant).to eq(other)
    end

    it "does not equal grant with different caller_id" do
      other = described_class.new(caller_id: "dev-team", capabilities: ["admin.jobs.*"])
      expect(grant).not_to eq(other)
    end
  end
end
