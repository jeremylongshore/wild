# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::WildcardMatcher do
  describe ".matches?" do
    it "matches exact capability name without wildcard" do
      expect(described_class.matches?("admin.jobs.view", "admin.jobs.view")).to be true
    end

    it "does not match different exact names" do
      expect(described_class.matches?("admin.jobs.view", "admin.jobs.retry")).to be false
    end

    it "matches trailing wildcard" do
      expect(described_class.matches?("admin.jobs.*", "admin.jobs.retry")).to be true
      expect(described_class.matches?("admin.jobs.*", "admin.jobs.view")).to be true
    end

    it "does not match beyond the wildcard segment" do
      expect(described_class.matches?("admin.jobs.*", "admin.users.delete")).to be false
    end

    it "matches mid-level wildcard" do
      expect(described_class.matches?("admin.*", "admin.jobs.retry")).to be true
    end

    it "matches root wildcard" do
      expect(described_class.matches?("*", "admin.jobs.view")).to be true
    end

    it "does not match prefix mismatch" do
      expect(described_class.matches?("ops.jobs.*", "admin.jobs.view")).to be false
    end
  end

  describe ".resolve_patterns" do
    let(:cap_names) { %w[admin.jobs.view admin.jobs.retry admin.users.delete admin.system.shutdown] }

    it "resolves wildcard patterns to matching capability names" do
      result = described_class.resolve_patterns(["admin.jobs.*"], cap_names)
      expect(result).to match_array(%w[admin.jobs.view admin.jobs.retry])
    end

    it "resolves exact names" do
      result = described_class.resolve_patterns(["admin.jobs.view"], cap_names)
      expect(result).to eq(["admin.jobs.view"])
    end

    it "resolves multiple patterns with deduplication" do
      result = described_class.resolve_patterns(["admin.jobs.*", "admin.jobs.view"], cap_names)
      # admin.jobs.view appears twice via different patterns but unique in cap_names
      expect(result).to include("admin.jobs.view", "admin.jobs.retry")
    end

    it "returns empty array when no patterns match" do
      result = described_class.resolve_patterns(["nonexistent.*"], cap_names)
      expect(result).to be_empty
    end
  end
end
