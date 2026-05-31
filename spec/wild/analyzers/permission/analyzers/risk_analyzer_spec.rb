# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::RiskAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when a wildcard covers a medium-risk capability (threshold: medium)" do
      it "returns a wildcard_on_critical finding" do
        findings = analyzer.analyze(standard_capabilities, [ops_grant])
        wildcard_findings = findings.select { |f| f.type == :wildcard_on_critical }
        expect(wildcard_findings).not_to be_empty
      end

      it "includes caller_id and pattern in evidence" do
        findings = analyzer.analyze(standard_capabilities, [ops_grant])
        f = findings.find { |fi| fi.type == :wildcard_on_critical }
        expect(f.evidence[:caller_id]).to eq("ops-team")
        expect(f.evidence[:pattern]).to eq("admin.jobs.*")
      end
    end

    context "when a wildcard covers a critical capability" do
      let(:admin_wildcard_grant) do
        Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "superadmin", capabilities: ["admin.*"]
        )
      end

      it "returns a critical-severity finding" do
        findings = analyzer.analyze(standard_capabilities, [admin_wildcard_grant])
        critical = findings.select { |f| f.severity == :critical }
        expect(critical).not_to be_empty
      end
    end

    context "when threshold is set to high" do
      it "does not flag medium-risk capabilities" do
        Wild.configure { |c| c.analyzers.permission.wildcard_risk_threshold = "high" }
        analyzer = described_class.new
        findings = analyzer.analyze(standard_capabilities, [ops_grant])
        caps_flagged = findings.select { |f| f.type == :wildcard_on_critical }.map { |f| f.evidence[:capability] }
        expect(caps_flagged).not_to include("admin.jobs.retry")
      end
    end

    context "when a grant with no expiry covers elevated permissions" do
      it "returns a no_expiry_elevated finding" do
        findings = analyzer.analyze(standard_capabilities, [ops_grant])
        no_expiry = findings.select { |f| f.type == :no_expiry_elevated }
        expect(no_expiry).not_to be_empty
      end
    end

    context "when a grant with expiry covers elevated permissions" do
      it "does not return no_expiry_elevated finding" do
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "temp", capabilities: ["admin.jobs.retry"], expires_at: "2099-01-01"
        )
        findings = analyzer.analyze(standard_capabilities, [g])
        expect(findings.select { |f| f.type == :no_expiry_elevated }).to be_empty
      end
    end

    context "when only low-risk capabilities exist" do
      it "returns no risk findings" do
        caps = [low_cap]
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.*"]
        )
        findings = analyzer.analyze(caps, [g])
        expect(findings.select { |f| %i[wildcard_on_critical no_expiry_elevated].include?(f.type) }).to be_empty
      end
    end

    context "with no grants" do
      it "returns empty findings" do
        expect(analyzer.analyze(standard_capabilities, [])).to be_empty
      end
    end
  end
end
