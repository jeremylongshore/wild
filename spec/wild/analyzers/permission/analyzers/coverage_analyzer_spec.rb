# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::CoverageAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    it "returns one CoverageReport per unique caller_id" do
      reports = analyzer.analyze(standard_capabilities, standard_grants)
      expect(reports.map(&:caller_id)).to match_array(%w[ops-team dev-intern])
    end

    it "resolves wildcard patterns into concrete granted capabilities" do
      reports = analyzer.analyze(standard_capabilities, [ops_grant])
      ops_report = reports.find { |r| r.caller_id == "ops-team" }
      expect(ops_report.granted_capabilities).to include("admin.jobs.view", "admin.jobs.retry")
    end

    it "places unmatched capabilities in denied_capabilities" do
      reports = analyzer.analyze(standard_capabilities, [intern_grant])
      intern = reports.find { |r| r.caller_id == "dev-intern" }
      expect(intern.denied_capabilities).to include("admin.jobs.retry", "admin.users.delete")
    end

    it "populates grant_chain with contributing grants" do
      reports = analyzer.analyze(standard_capabilities, [intern_grant])
      intern = reports.find { |r| r.caller_id == "dev-intern" }
      expect(intern.grant_chain["admin.jobs.view"]).to include(intern_grant)
    end

    it "returns empty array when no grants" do
      expect(analyzer.analyze(standard_capabilities, [])).to be_empty
    end

    it "returns empty coverage when no capabilities defined" do
      reports = analyzer.analyze([], [intern_grant])
      intern = reports.find { |r| r.caller_id == "dev-intern" }
      expect(intern.granted_capabilities).to be_empty
      expect(intern.denied_capabilities).to be_empty
    end
  end

  describe "#coverage_for" do
    it "returns a CoverageReport for the specified caller" do
      report = analyzer.coverage_for("ops-team", standard_capabilities, standard_grants)
      expect(report).to be_a(Wild::Analyzers::Permission::Models::CoverageReport)
      expect(report.caller_id).to eq("ops-team")
    end

    it "returns report with empty grants when caller has no grants" do
      report = analyzer.coverage_for("unknown-caller", standard_capabilities, standard_grants)
      expect(report.granted_capabilities).to be_empty
      expect(report.denied_capabilities).to match_array(standard_capabilities.map(&:name))
    end
  end
end
