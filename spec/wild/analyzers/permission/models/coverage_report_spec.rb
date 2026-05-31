# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Models::CoverageReport do
  subject(:report) do
    described_class.new(
      caller_id: "ops-team",
      granted_capabilities: %w[admin.jobs.view admin.jobs.retry],
      denied_capabilities: %w[admin.users.delete admin.system.shutdown],
      grant_chain: {}
    )
  end

  describe "#caller_id" do
    it "returns the caller id" do
      expect(report.caller_id).to eq("ops-team")
    end
  end

  describe "#coverage_ratio" do
    it "returns fraction of granted to total" do
      expect(report.coverage_ratio).to be_within(0.001).of(0.5)
    end

    it "returns 0.0 when no capabilities exist" do
      empty = described_class.new(
        caller_id: "x", granted_capabilities: [], denied_capabilities: [], grant_chain: {}
      )
      expect(empty.coverage_ratio).to eq(0.0)
    end

    it "returns 1.0 when all capabilities are granted" do
      full = described_class.new(
        caller_id: "x",
        granted_capabilities: %w[a b c],
        denied_capabilities: [],
        grant_chain: {}
      )
      expect(full.coverage_ratio).to eq(1.0)
    end
  end

  describe "frozen attributes" do
    it "freezes granted_capabilities" do
      expect(report.granted_capabilities).to be_frozen
    end

    it "freezes denied_capabilities" do
      expect(report.denied_capabilities).to be_frozen
    end
  end
end
