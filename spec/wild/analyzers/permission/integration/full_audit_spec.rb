# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

require "tmpdir"
require "json"

RSpec.describe "Full audit pipeline" do
  let(:tmpdir) { Dir.mktmpdir }
  let(:caps_path) { write_capabilities_yaml(default_capabilities_yaml_entries, tmpdir) }
  let(:grants_path) { write_grants_yaml(default_grants_yaml_entries, tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  it "audits capabilities and grants loaded from YAML files" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    expect(report).to be_a(Wild::Analyzers::Permission::Models::AuditReport)
    expect(report.findings).not_to be_empty
    expect(report.coverage_reports).not_to be_empty
  end

  it "produces coverage reports for all callers in grants.yml" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    caller_ids = report.coverage_reports.map(&:caller_id)
    expect(caller_ids).to match_array(%w[ops-team dev-intern])
  end

  it "flags the ops-team wildcard as risky" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    expect(report.findings.any? { |f| f.type == :wildcard_on_critical }).to be true
  end

  it "flags ops-team no-expiry grant for elevated capabilities" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    expect(report.findings.any? { |f| f.type == :no_expiry_elevated }).to be true
  end

  it "identifies orphaned capabilities not covered by any grant" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    orphan_caps = report.findings
                        .select { |f| f.type == :orphan_capability }
                        .map { |f| f.evidence[:capability] }
    # admin.users.delete and admin.system.shutdown are not matched by admin.jobs.*
    expect(orphan_caps).to include("admin.users.delete", "admin.system.shutdown")
  end

  # Fowler finding 1, the documenting integration test: an operator-grade audit
  # run against a deep ACYCLIC prerequisite chain must produce zero critical
  # findings. Before the tri-color DFS fix, a chain deeper than
  # max_prerequisite_depth fabricated a :circular_prerequisite/critical finding.
  it "produces zero critical findings for a deep acyclic prerequisite chain" do
    chain = (1..15).map do |i|
      prereqs = i < 15 ? ["cap.#{i + 1}"] : []
      { "name" => "cap.#{i}", "description" => "link #{i}", "risk_level" => "low",
        "prerequisites" => prereqs, "tags" => [] }
    end
    deep_caps = write_capabilities_yaml(chain, tmpdir)
    deep_grants = write_grants_yaml(
      [{ "caller_id" => "svc", "capabilities" => ["cap.1"], "context" => {}, "expires_at" => nil }],
      tmpdir
    )

    report = Wild::Analyzers::Permission.audit(
      capabilities_path: deep_caps, grants_path: deep_grants
    )

    expect(report.findings.count { |f| f.type == :circular_prerequisite }).to eq(0)
    expect(report.findings.count { |f| f.severity == :critical }).to eq(0)
  end

  it "can be exported to JSON" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    json_output = Wild::Analyzers::Permission::Export::JsonExporter.new.export(report)
    parsed = JSON.parse(json_output)
    expect(parsed["findings"]).not_to be_empty
    expect(parsed["coverage_reports"]).not_to be_empty
  end

  it "can be exported to Markdown" do
    report = Wild::Analyzers::Permission.audit(
      capabilities_path: caps_path, grants_path: grants_path
    )
    md = Wild::Analyzers::Permission::Export::MarkdownExporter.new.export(report)
    expect(md).to include("# Permission Audit Report")
    expect(md).to include("ops-team")
  end

  it "raises ConfigurationError when capabilities_path is not set" do
    expect { Wild::Analyzers::Permission.audit(grants_path: grants_path) }
      .to raise_error(Wild::ConfigurationError, /capabilities_path/)
  end

  it "raises ConfigurationError when grants_path is not set" do
    expect { Wild::Analyzers::Permission.audit(capabilities_path: caps_path) }
      .to raise_error(Wild::ConfigurationError, /grants_path/)
  end

  it "raises LoadError when capabilities file is missing" do
    expect do
      Wild::Analyzers::Permission.audit(
        capabilities_path: "/nonexistent/caps.yml", grants_path: grants_path
      )
    end.to raise_error(Wild::Analyzers::Permission::LoadError)
  end

  context "with configure block" do
    it "uses paths from configuration" do
      Wild.configure do |c|
        c.analyzers.permission.capabilities_path = caps_path
        c.analyzers.permission.grants_path = grants_path
      end
      report = Wild::Analyzers::Permission.audit
      expect(report).to be_a(Wild::Analyzers::Permission::Models::AuditReport)
    end
  end

  context "when all grants are clean" do
    it "returns minimal findings for safe configs" do
      safe_caps = [{ "name" => "reports.view", "description" => "View reports", "risk_level" => "low",
                     "prerequisites" => [], "tags" => ["reports"] }]
      safe_grants = [{ "caller_id" => "analyst", "capabilities" => ["reports.view"],
                       "context" => {}, "expires_at" => "2099-12-31" }]
      safe_caps_path = write_capabilities_yaml(safe_caps, tmpdir)
      safe_grants_path = write_grants_yaml(safe_grants, tmpdir)
      report = Wild::Analyzers::Permission.audit(
        capabilities_path: safe_caps_path, grants_path: safe_grants_path
      )
      error_or_critical = report.findings.select { |f| %i[error critical].include?(f.severity) }
      expect(error_or_critical).to be_empty
    end
  end
end

# rubocop:enable RSpec/DescribeClass
