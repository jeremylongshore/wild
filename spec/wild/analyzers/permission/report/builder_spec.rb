# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Report::Builder do
  subject(:builder) { described_class.new(standard_capabilities, standard_grants) }

  describe "#build" do
    it "returns an AuditReport" do
      report = builder.build
      expect(report).to be_a(Wild::Analyzers::Permission::Models::AuditReport)
    end

    it "includes findings from all analyzers" do
      report = builder.build
      finding_types = report.findings.map(&:type)
      # ops-team has a wildcard and no expiry; these should both be flagged
      expect(finding_types).to include(:wildcard_on_critical, :no_expiry_elevated)
    end

    it "includes coverage reports for all callers" do
      report = builder.build
      expect(report.coverage_reports.map(&:caller_id)).to match_array(%w[ops-team dev-intern])
    end

    it "produces a report with a generated_at timestamp" do
      report = builder.build
      expect(report.generated_at).to be_a(Time)
    end

    it "sorts findings by severity descending" do
      report = builder.build
      ranks = report.findings.map { |f| Wild::Analyzers::Permission::Models::Finding::SEVERITY_RANKS[f.severity] }
      expect(ranks).to eq(ranks.sort.reverse)
    end

    context "with clean configs (no risks)" do
      it "returns no error or critical findings" do
        low_only_cap = Wild::Analyzers::Permission::Models::Capability.new(
          name: "safe.read", risk_level: "low"
        )
        safe_grant = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "reader", capabilities: ["safe.read"], expires_at: "2099-01-01"
        )
        report = described_class.new([low_only_cap], [safe_grant]).build
        expect(report.findings.select { |f| %i[error critical].include?(f.severity) }).to be_empty
      end
    end
  end
end
