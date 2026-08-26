# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::WildcardMatcher do
  describe ".wildcard?" do
    it "is true for any pattern containing the wildcard metacharacter" do
      expect(described_class.wildcard?("admin.jobs.*")).to be true
      expect(described_class.wildcard?("*")).to be true
      expect(described_class.wildcard?("admin.*.retry")).to be true
    end

    it "is false for a pattern with no wildcard metacharacter" do
      expect(described_class.wildcard?("admin.jobs.view")).to be false
      expect(described_class.wildcard?("")).to be false
    end
  end

  # Review wave finding f-l05-2: wildcard detection (pattern.include?("*")) was
  # previously duplicated verbatim at 6 call sites (orphan_analyzer, this file,
  # risk_analyzer, shadow_analyzer, consistency_analyzer, models/grant). All 6
  # now delegate to .wildcard? above, so the grammar lives in one place.
  describe "callers that centralize wildcard detection through .wildcard?" do
    let(:capability) { Wild::Analyzers::Permission::Models::Capability.new(name: "admin.jobs.retry") }

    it "Models::Grant#wildcard_capabilities uses .wildcard? to select wildcard patterns" do
      grant = Wild::Analyzers::Permission::Models::Grant.new(
        caller_id: "svc:test", capabilities: ["admin.jobs.*", "admin.jobs.view"]
      )
      expect(grant.wildcard_capabilities).to eq(["admin.jobs.*"])
    end

    it "OrphanAnalyzer does not flag a wildcard grant as referencing a missing capability" do
      grant = Wild::Analyzers::Permission::Models::Grant.new(caller_id: "svc:test", capabilities: ["admin.*"])
      findings = Wild::Analyzers::Permission::Analyzers::OrphanAnalyzer.new.analyze([capability], [grant])
      expect(findings.map(&:type)).not_to include(:grant_references_missing_capability)
    end
  end

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

  describe "compiled Regexp caching" do
    # Review wave finding f-l05-1: matches? used to Regexp.new a fresh
    # compiled pattern on every call. Benchmark cited in the finding:
    # 300_000 calls of matches?("admin.jobs.*", "admin.jobs.retry") took
    # ~3.3s uncached vs ~0.17s with a pre-compiled Regexp (~20x). This spec
    # does not assert on wall-clock time (flaky by nature); it pins the
    # actual mechanism, that repeated calls for the same pattern reuse one
    # compiled Regexp object rather than allocating a new one each time.
    it "returns the same compiled Regexp object for repeated calls with the same pattern string" do
      first = described_class.send(:compiled_regex, "admin.jobs.*")
      second = described_class.send(:compiled_regex, "admin.jobs.*")

      expect(first).to equal(second)
    end

    it "compiles a distinct Regexp per distinct pattern string" do
      a = described_class.send(:compiled_regex, "admin.jobs.*")
      b = described_class.send(:compiled_regex, "admin.users.*")

      expect(a).not_to equal(b)
      expect(a.source).not_to eq(b.source)
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
