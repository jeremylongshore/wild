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

      # Fowler finding 1: a real 2-node cycle must be reported ONCE, not N times
      # (the old path-local visited + per-node re-entry re-discovered each cycle
      # from every node on it).
      it "reports a 2-node cycle exactly once, not once per node on it" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["b"])
        cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["a"])
        findings = analyzer.analyze([cap_a, cap_b], [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(1)
      end

      it "detects a 3-node cycle a -> b -> c -> a" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["b"])
        cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["c"])
        cap_c = Wild::Analyzers::Permission::Models::Capability.new(name: "c", prerequisites: ["a"])
        findings = analyzer.analyze([cap_a, cap_b, cap_c], [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(1)
      end

      # Degenerate cycle (Fowler sign-off follow-up): a self-edge is a GRAY
      # back-edge to the node still on the stack — the most likely regression
      # under a future "skip self-references" optimization.
      it "detects a self-loop a -> a as exactly one cycle" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: ["a"])
        findings = analyzer.analyze([cap_a], [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(1)
      end
    end

    context "with a long ACYCLIC prerequisite chain (Fowler finding 1 — false-positive guard)" do
      # The bug: detect_cycle returned a fake [name, "..."] cycle for any chain
      # deeper than max_prerequisite_depth. A 15-deep STRAIGHT LINE has no cycle
      # and must produce ZERO :circular_prerequisite findings — even with the
      # depth knob set low. "A security tool that invents critical findings
      # teaches operators to ignore critical findings."
      let(:deep_acyclic_chain) do
        # cap.1 -> cap.2 -> ... -> cap.15 (cap.15 has no prerequisite — terminates)
        (1..15).map do |i|
          prereqs = i < 15 ? ["cap.#{i + 1}"] : []
          Wild::Analyzers::Permission::Models::Capability.new(name: "cap.#{i}", prerequisites: prereqs)
        end
      end

      it "produces ZERO circular_prerequisite findings for a 15-deep straight line" do
        findings = analyzer.analyze(deep_acyclic_chain, [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(0)
      end

      it "produces zero circular findings even when max_prerequisite_depth is set low" do
        Wild.configure { |c| c.analyzers.permission.max_prerequisite_depth = 5 }
        findings = described_class.new.analyze(deep_acyclic_chain, [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(0)
      end

      it "terminates without raising" do
        expect { analyzer.analyze(deep_acyclic_chain, []) }.not_to raise_error
      end
    end

    context "with a diamond (shared-but-acyclic) prerequisite graph" do
      # a -> {b, c}; b -> d; c -> d. d is reached twice but there is NO cycle.
      # A naive 'seen this node before' check would false-positive here; tri-color
      # DFS must not.
      it "does not flag a diamond as circular" do
        cap_a = Wild::Analyzers::Permission::Models::Capability.new(name: "a", prerequisites: %w[b c])
        cap_b = Wild::Analyzers::Permission::Models::Capability.new(name: "b", prerequisites: ["d"])
        cap_c = Wild::Analyzers::Permission::Models::Capability.new(name: "c", prerequisites: ["d"])
        cap_d = Wild::Analyzers::Permission::Models::Capability.new(name: "d", prerequisites: [])
        findings = analyzer.analyze([cap_a, cap_b, cap_c, cap_d], [])
        expect(findings.count { |f| f.type == :circular_prerequisite }).to eq(0)
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

    # NOTE: the former "max_prerequisite_depth prevents infinite loops" example
    # was deleted (Fowler finding 10) — it built a 15-deep ACYCLIC chain, set
    # the depth limit to 5, and only asserted `not_to raise_error`, thereby
    # documenting the false-positive as a feature. Tri-color DFS makes the
    # depth limit unnecessary for cycle safety; the acyclic-chain guard above
    # replaces it.
  end
end
