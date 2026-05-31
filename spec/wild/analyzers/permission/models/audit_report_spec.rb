# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Models::AuditReport do
  subject(:report) do
    described_class.new(
      findings: [warning_finding, critical_finding, info_finding],
      coverage_reports: [coverage]
    )
  end

  let(:critical_finding) do
    Wild::Analyzers::Permission::Models::Finding.new(
      type: :wildcard_on_critical, severity: :critical, message: "Critical!"
    )
  end
  let(:warning_finding) do
    Wild::Analyzers::Permission::Models::Finding.new(
      type: :no_expiry_elevated, severity: :warning, message: "Warning!"
    )
  end
  let(:info_finding) do
    Wild::Analyzers::Permission::Models::Finding.new(
      type: :orphan_capability, severity: :info, message: "Info"
    )
  end
  let(:coverage) do
    Wild::Analyzers::Permission::Models::CoverageReport.new(
      caller_id: "ops-team",
      granted_capabilities: ["admin.jobs.view"],
      denied_capabilities: [],
      grant_chain: {}
    )
  end

  describe "#findings" do
    it "sorts findings by severity descending" do
      expect(report.findings.map(&:severity)).to eq(%i[critical warning info])
    end

    it "freezes the findings array" do
      expect(report.findings).to be_frozen
    end
  end

  describe "#summary" do
    it "includes total_findings" do
      expect(report.summary[:total_findings]).to eq(3)
    end

    it "counts by severity" do
      expect(report.summary[:by_severity][:critical]).to eq(1)
      expect(report.summary[:by_severity][:warning]).to eq(1)
      expect(report.summary[:by_severity][:info]).to eq(1)
      expect(report.summary[:by_severity][:error]).to eq(0)
    end

    it "includes generated_at" do
      expect(report.summary[:generated_at]).to be_a(String)
    end
  end

  describe "#findings_by_severity" do
    it "returns findings matching the given severity" do
      expect(report.findings_by_severity(:critical)).to eq([critical_finding])
    end

    it "returns empty array for severity with no findings" do
      expect(report.findings_by_severity(:error)).to be_empty
    end
  end
end
