# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

require "tmpdir"

RSpec.describe "Edge cases and adversarial inputs" do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  describe "Special characters in capability names" do
    it "handles capability names with hyphens" do
      cap = Wild::Analyzers::Permission::Models::Capability.new(name: "admin-jobs.view")
      grant = Wild::Analyzers::Permission::Models::Grant.new(caller_id: "x", capabilities: ["admin-jobs.view"])
      analyzer = Wild::Analyzers::Permission::Analyzers::ConsistencyAnalyzer.new
      expect(analyzer.analyze([cap], [grant])).to be_empty
    end

    it "handles capability names with unicode characters" do
      cap = Wild::Analyzers::Permission::Models::Capability.new(name: "admin.télécharger")
      expect(cap.name).to eq("admin.télécharger")
    end

    it "handles very long capability names" do
      long_name = "admin.#{"x" * 500}"
      cap = Wild::Analyzers::Permission::Models::Capability.new(name: long_name)
      expect(cap.name).to eq(long_name)
    end
  end

  describe "Large scale performance" do
    it "analyzes 500 capabilities and 200 grants in under 5 seconds" do
      caps = (1..500).map do |i|
        Wild::Analyzers::Permission::Models::Capability.new(name: "cap.group#{i % 10}.item#{i}", risk_level: "low")
      end
      grants = (1..200).map do |i|
        Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "caller-#{i}",
          capabilities: ["cap.group#{i % 10}.*"],
          expires_at: "2099-01-01"
        )
      end
      start = Time.now.utc
      Wild::Analyzers::Permission::Report::Builder.new(caps, grants).build
      elapsed = Time.now.utc - start
      expect(elapsed).to be < 5.0
    end
  end

  describe "Wildcard matching edge cases" do
    it "matches a single-segment wildcard" do
      expect(Wild::Analyzers::Permission::Analyzers::WildcardMatcher.matches?("*", "anything")).to be true
    end

    it "matches deeply nested wildcard" do
      expect(Wild::Analyzers::Permission::Analyzers::WildcardMatcher.matches?("a.b.c.*", "a.b.c.d.e")).to be true
    end

    it "does not match with partial prefix" do
      expect(Wild::Analyzers::Permission::Analyzers::WildcardMatcher.matches?("admin.jobs",
                                                                              "admin.jobs.view")).to be false
    end

    it "handles dot in pattern as literal dot via Regexp.escape" do
      # 'admin.jobs.*' should NOT match 'adminXjobs.view'
      expect(Wild::Analyzers::Permission::Analyzers::WildcardMatcher.matches?("admin.jobs.*",
                                                                              "adminXjobs.view")).to be false
    end
  end

  describe "Grant with nil capabilities array entries" do
    it "does not raise when context is nil in Grant" do
      g = Wild::Analyzers::Permission::Models::Grant.new(caller_id: "x", capabilities: ["cap.one"], context: nil)
      expect(g.context).to eq({})
    end
  end

  # No "Configuration boundary conditions" example group: the only test it held,
  # "accepts max_prerequisite_depth of 1", was removed with the knob itself
  # (wild-0e0) — it set a dead config field and asserted the setter ran, a
  # textbook F3 vanity test of absent behavior. The old gem's Configuration also
  # did per-setter validation (wildcard_risk_threshold must be a known risk
  # level) and froze itself after `configure`; Wild's typed Struct + no-freeze
  # design dropped both, and the 2 specs covering them were deleted rather than
  # rewritten (F3 — no vanity tests of absent behavior). If validation returns
  # as a Role 6 follow-up, the specs come back with it.

  describe "Circular prerequisite with three-node chain" do
    it "detects three-way circular prerequisites" do
      cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["b"])
      cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["c"])
      cap_c = Wild::Analyzers::Permission::Models::Capability.new(name: "c", prerequisites: ["a"])
      analyzer = Wild::Analyzers::Permission::Analyzers::PrerequisiteAnalyzer.new
      findings = analyzer.analyze([cap_a, cap_b, cap_c], [])
      expect(findings.any? { |f| f.type == :circular_prerequisite }).to be true
    end
  end

  describe "Orphan analyzer with wildcard that covers everything" do
    it "returns no orphans when super-wildcard grant exists" do
      caps = standard_capabilities
      super_grant = Wild::Analyzers::Permission::Models::Grant.new(caller_id: "root", capabilities: ["*"])
      analyzer = Wild::Analyzers::Permission::Analyzers::OrphanAnalyzer.new
      orphans = analyzer.analyze(caps, [super_grant]).select { |f| f.type == :orphan_capability }
      expect(orphans).to be_empty
    end
  end

  describe "Shadow analyzer with multiple shadowing grants" do
    it "reports all shadowed explicit grants" do
      explicit = Wild::Analyzers::Permission::Models::Grant.new(
        caller_id: "power-user",
        capabilities: %w[admin.jobs.view admin.jobs.retry]
      )
      wildcard = Wild::Analyzers::Permission::Models::Grant.new(
        caller_id: "power-user",
        capabilities: ["admin.*"]
      )
      analyzer = Wild::Analyzers::Permission::Analyzers::ShadowAnalyzer.new
      findings = analyzer.analyze(standard_capabilities, [explicit, wildcard])
      shadowed_caps = findings.select { |f| f.type == :shadowed_grant }.map { |f| f.evidence[:capability] }
      expect(shadowed_caps).to include("admin.jobs.view", "admin.jobs.retry")
    end
  end

  describe "Markdown exporter with special characters in caller IDs" do
    let(:pipe_report) do
      finding = Wild::Analyzers::Permission::Models::Finding.new(
        type: :info_type, severity: :info, message: "A | B | C message"
      )
      coverage = Wild::Analyzers::Permission::Models::CoverageReport.new(
        caller_id: "caller|with|pipes",
        granted_capabilities: ["cap.one"],
        denied_capabilities: [],
        grant_chain: {}
      )
      Wild::Analyzers::Permission::Models::AuditReport.new(
        findings: [finding],
        coverage_reports: [coverage]
      )
    end

    it "does not break markdown table with pipe characters in caller_id" do
      output = Wild::Analyzers::Permission::Export::MarkdownExporter.new.export(pipe_report)
      lines = output.split("\n")
      header_pattern = /Metric|Severity|Caller/
      data_rows = lines.select { |l| l.start_with?("|") && !l.start_with?("|--") && !l.match?(header_pattern) }
      expect(data_rows).to all(start_with("|"))
    end
  end

  describe "YAML with path-traversal-like capability names" do
    it "treats them as regular string names without executing anything" do
      entries = [{ "name" => "../../etc/passwd", "risk_level" => "low", "prerequisites" => [], "tags" => [] }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = Wild::Analyzers::Permission::Loaders::CapabilitiesLoader.load(path)
      expect(caps.first.name).to eq("../../etc/passwd")
    end
  end
end

# rubocop:enable RSpec/DescribeClass
