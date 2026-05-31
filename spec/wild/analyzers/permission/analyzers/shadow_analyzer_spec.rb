# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::ShadowAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when an explicit grant is shadowed by a wildcard from the same caller" do
      let(:explicit_grant) do
        Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "ops-team", capabilities: ["admin.jobs.view"]
        )
      end
      let(:wildcard_grant) do
        Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "ops-team", capabilities: ["admin.jobs.*"]
        )
      end

      it "returns a shadowed_grant finding" do
        findings = analyzer.analyze(standard_capabilities, [explicit_grant, wildcard_grant])
        shadowed = findings.select { |f| f.type == :shadowed_grant }
        expect(shadowed).not_to be_empty
      end

      it "includes caller_id and capability in evidence" do
        findings = analyzer.analyze(standard_capabilities, [explicit_grant, wildcard_grant])
        finding = findings.find { |f| f.type == :shadowed_grant }
        expect(finding.evidence[:caller_id]).to eq("ops-team")
        expect(finding.evidence[:capability]).to eq("admin.jobs.view")
        expect(finding.evidence[:shadowed_by]).to include("admin.jobs.*")
      end

      it "returns warning severity" do
        findings = analyzer.analyze(standard_capabilities, [explicit_grant, wildcard_grant])
        finding = findings.find { |f| f.type == :shadowed_grant }
        expect(finding.severity).to eq(:warning)
      end
    end

    context "when grants are for different callers" do
      it "does not flag cross-caller shadows" do
        explicit = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "caller-a", capabilities: ["admin.jobs.view"]
        )
        wildcard = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "caller-b", capabilities: ["admin.jobs.*"]
        )
        findings = analyzer.analyze(standard_capabilities, [explicit, wildcard])
        expect(findings.select { |f| f.type == :shadowed_grant }).to be_empty
      end
    end

    context "when there are no shadows" do
      it "returns no shadowed_grant findings" do
        findings = analyzer.analyze(standard_capabilities, standard_grants)
        expect(findings.select { |f| f.type == :shadowed_grant }).to be_empty
      end
    end

    context "when capability does not exist in the capabilities list" do
      it "does not flag shadows for non-existent capabilities" do
        explicit = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["nonexistent.cap"]
        )
        wildcard = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["nonexistent.*"]
        )
        findings = analyzer.analyze(standard_capabilities, [explicit, wildcard])
        expect(findings.select { |f| f.type == :shadowed_grant }).to be_empty
      end
    end

    context "with no grants" do
      it "returns empty findings" do
        expect(analyzer.analyze(standard_capabilities, [])).to be_empty
      end
    end
  end
end
