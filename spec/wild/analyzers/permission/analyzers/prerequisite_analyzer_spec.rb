# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Analyzers::PrerequisiteAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "when all prerequisites are satisfied" do
      it "returns no prerequisite findings" do
        findings = analyzer.analyze(standard_capabilities, standard_grants)
        prereq_types = %i[missing_prerequisite circular_prerequisite unsatisfiable_prerequisite]
        expect(findings.select { |f| prereq_types.include?(f.type) }).to be_empty
      end
    end

    context "when a capability has a missing prerequisite" do
      it "returns a missing_prerequisite finding" do
        cap = Wild::Analyzers::Permission::Models::Capability.new(
          name: "admin.jobs.retry",
          prerequisites: ["nonexistent.cap"]
        )
        findings = analyzer.analyze([cap], [])
        expect(findings.any? { |f| f.type == :missing_prerequisite }).to be true
      end

      it "includes the missing prerequisite in evidence" do
        cap = Wild::Analyzers::Permission::Models::Capability.new(
          name: "admin.jobs.retry",
          prerequisites: ["ghost.cap"]
        )
        finding = analyzer.analyze([cap], []).find { |f| f.type == :missing_prerequisite }
        expect(finding.evidence[:missing_prerequisite]).to eq("ghost.cap")
        expect(finding.evidence[:capability]).to eq("admin.jobs.retry")
      end
    end

    context "when a circular prerequisite chain exists" do
      it "returns a circular_prerequisite finding" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["b"])
        cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["a"])
        findings = analyzer.analyze([cap_a, cap_b], [])
        expect(findings.any? { |f| f.type == :circular_prerequisite }).to be true
      end

      it "reports critical severity for circular chains" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["b"])
        cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["a"])
        finding = analyzer.analyze([cap_a, cap_b], []).find { |f| f.type == :circular_prerequisite }
        expect(finding.severity).to eq(:critical)
      end
    end

    context "when a grant includes a capability with an unsatisfiable prerequisite" do
      it "returns an unsatisfiable_prerequisite finding" do
        cap = Wild::Analyzers::Permission::Models::Capability.new(
          name: "admin.jobs.retry",
          prerequisites: ["undefined.prereq"]
        )
        g = Wild::Analyzers::Permission::Models::Grant.new(
          caller_id: "x", capabilities: ["admin.jobs.retry"]
        )
        findings = analyzer.analyze([cap], [g])
        expect(findings.any? { |f| f.type == :unsatisfiable_prerequisite }).to be true
      end
    end

    context "with capabilities that have no prerequisites" do
      it "returns no prerequisite findings" do
        cap = Wild::Analyzers::Permission::Models::Capability.new(name: "standalone.cap")
        expect(analyzer.analyze([cap], [])).to be_empty
      end
    end

    context "when max_prerequisite_depth prevents infinite loops" do
      it "terminates and flags a chain exceeding max depth" do
        caps = (1..15).map do |i|
          Wild::Analyzers::Permission::Models::Capability.new(
            name: "cap.#{i}",
            prerequisites: ["cap.#{i + 1}"]
          )
        end
        Wild.configure { |c| c.analyzers.permission.max_prerequisite_depth = 5 }
        analyzer = described_class.new
        expect { analyzer.analyze(caps, []) }.not_to raise_error
      end
    end
  end
end
