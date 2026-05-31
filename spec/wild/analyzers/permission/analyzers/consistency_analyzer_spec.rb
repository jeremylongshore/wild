# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::ConsistencyAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when all explicit capabilities in grants exist" do
      it "returns no findings" do
        findings = analyzer.analyze(standard_capabilities, [intern_grant])
        expect(findings).to be_empty
      end
    end

    context "when a grant references a non-existent capability" do
      it "returns a missing_reference finding" do
        bad_grant = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "attacker", capabilities: ["nonexistent.cap"]
        )
        findings = analyzer.analyze(standard_capabilities, [bad_grant])
        expect(findings.size).to eq(1)
        expect(findings.first.type).to eq(:missing_reference)
        expect(findings.first.severity).to eq(:error)
      end

      it "includes the missing capability in evidence" do
        bad_grant = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["ghost.cap"]
        )
        finding = analyzer.analyze(standard_capabilities, [bad_grant]).first
        expect(finding.evidence[:capability]).to eq("ghost.cap")
        expect(finding.evidence[:caller_id]).to eq("x")
      end
    end

    context "when wildcards are present" do
      it "does not flag wildcards as missing references" do
        findings = analyzer.analyze(standard_capabilities, [ops_grant])
        expect(findings).to be_empty
      end
    end

    context "with multiple bad grants" do
      it "returns one finding per bad reference" do
        bad_grants = [
          Wild::Analyzers::Permission::Models::Grant.new(caller_id: "a", capabilities: ["missing.one", "missing.two"]),
          Wild::Analyzers::Permission::Models::Grant.new(caller_id: "b", capabilities: ["missing.three"])
        ]
        findings = analyzer.analyze(standard_capabilities, bad_grants)
        expect(findings.size).to eq(3)
      end
    end

    context "when capabilities list is empty" do
      it "flags all explicit grant capabilities as missing" do
        findings = analyzer.analyze([], [intern_grant])
        expect(findings.size).to eq(1)
        expect(findings.first.type).to eq(:missing_reference)
      end
    end
  end
end
