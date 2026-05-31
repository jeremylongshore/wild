# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Coverage analysis pipeline" do
  subject(:analyzer) { Wild::Analyzers::Permission::Analyzers::CoverageAnalyzer.new }

  let(:caps) do
    %w[admin.jobs.view admin.jobs.retry admin.users.view admin.users.delete admin.system.reboot].map do |name|
      level = name.include?("delete") || name.include?("reboot") ? "high" : "low"
      Wild::Analyzers::Permission::Models::Capability.new(name: name, risk_level: level)
    end
  end

  let(:admin_grant) do
    Wild::Analyzers::Permission::Models::Grant.new(
      caller_id: "admin", capabilities: ["admin.*"], expires_at: nil
    )
  end

  let(:readonly_grant) do
    Wild::Analyzers::Permission::Models::Grant.new(
      caller_id: "readonly-bot", capabilities: ["admin.jobs.view", "admin.users.view"],
      expires_at: "2099-01-01"
    )
  end

  describe "admin caller with wildcard" do
    it "is granted all capabilities" do
      reports = analyzer.analyze(caps, [admin_grant])
      admin = reports.find { |r| r.caller_id == "admin" }
      expect(admin.granted_capabilities).to match_array(caps.map(&:name))
      expect(admin.denied_capabilities).to be_empty
    end

    it "has 100% coverage ratio" do
      reports = analyzer.analyze(caps, [admin_grant])
      admin = reports.find { |r| r.caller_id == "admin" }
      expect(admin.coverage_ratio).to eq(1.0)
    end
  end

  describe "readonly-bot caller with explicit grants" do
    it "is granted only the two view capabilities" do
      reports = analyzer.analyze(caps, [readonly_grant])
      bot = reports.find { |r| r.caller_id == "readonly-bot" }
      expect(bot.granted_capabilities).to match_array(%w[admin.jobs.view admin.users.view])
    end

    it "is denied the destructive capabilities" do
      reports = analyzer.analyze(caps, [readonly_grant])
      bot = reports.find { |r| r.caller_id == "readonly-bot" }
      expect(bot.denied_capabilities).to include("admin.users.delete", "admin.system.reboot")
    end

    it "has 40% coverage ratio" do
      reports = analyzer.analyze(caps, [readonly_grant])
      bot = reports.find { |r| r.caller_id == "readonly-bot" }
      expect(bot.coverage_ratio).to be_within(0.001).of(0.4)
    end
  end

  describe "coverage_for a specific caller not in grants" do
    it "returns 0.0 coverage ratio" do
      report = analyzer.coverage_for("unknown", caps, [admin_grant, readonly_grant])
      expect(report.coverage_ratio).to eq(0.0)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
