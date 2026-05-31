# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::OrphanAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when all capabilities are granted" do
      it "returns no orphan findings" do
        all_caps = [low_cap, medium_cap]
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.*"]
        )
        findings = analyzer.analyze(all_caps, [g])
        orphans = findings.select { |f| f.type == :orphan_capability }
        expect(orphans).to be_empty
      end
    end

    context "when a capability is never granted" do
      it "returns an orphan_capability finding" do
        caps = [low_cap, medium_cap, critical_cap]
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.*"]
        )
        findings = analyzer.analyze(caps, [g])
        orphans = findings.select { |f| f.type == :orphan_capability }
        orphan_names = orphans.map { |f| f.evidence[:capability] }
        expect(orphan_names).to include("admin.system.shutdown")
      end

      it "returns info severity for orphaned capabilities" do
        caps = [low_cap, critical_cap]
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.view"]
        )
        finding = analyzer.analyze(caps, [g]).find { |f| f.type == :orphan_capability }
        expect(finding.severity).to eq(:info)
      end
    end

    context "when a grant references a non-existent capability" do
      it "returns a grant_references_missing_capability finding" do
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["ghost.cap"]
        )
        findings = analyzer.analyze(standard_capabilities, [g])
        missing = findings.select { |f| f.type == :grant_references_missing_capability }
        expect(missing).not_to be_empty
      end

      it "does not flag wildcards as missing" do
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.*"]
        )
        findings = analyzer.analyze(standard_capabilities, [g])
        expect(findings.select { |f| f.type == :grant_references_missing_capability }).to be_empty
      end
    end

    context "with no grants at all" do
      it "flags all capabilities as orphans" do
        findings = analyzer.analyze(standard_capabilities, [])
        orphan_names = findings.select { |f| f.type == :orphan_capability }.map { |f| f.evidence[:capability] }
        expect(orphan_names).to match_array(standard_capabilities.map(&:name))
      end
    end

    context "with no capabilities" do
      it "returns no orphan findings" do
        g = Wild::Analyzers::Permission::Models::Grant.new(caller_id: "x", capabilities: ["some.cap"])
        findings = analyzer.analyze([], [g])
        expect(findings.select { |f| f.type == :orphan_capability }).to be_empty
      end
    end
  end
end
