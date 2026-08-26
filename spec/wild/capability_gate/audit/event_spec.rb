# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Audit::Event do
  let(:timestamp) { Time.utc(2026, 3, 17, 12, 0, 0) }

  let(:capability) do
    Wild::CapabilityGate::Capability.new(
      name: :privileged_introspection,
      description: "Extended introspection",
      risk_level: :elevated,
      prerequisites: [
        Wild::CapabilityGate::Prerequisite.new(type: :file_exists, path: "/tmp/attestation.md")
      ]
    )
  end

  let(:registry) { Wild::CapabilityGate::Registry.new([capability]) }

  describe ".from_evaluation" do
    context "with an allowed result" do
      let(:result) do
        Wild::CapabilityGate::EvaluationResult.allowed(
          capability_name: :privileged_introspection,
          caller_id: "service-account:introspection-agent",
          prerequisites_checked: [:file_exists],
          timestamp: timestamp
        )
      end

      it 'creates an event with outcome "allow"' do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.outcome).to eq("allow")
        expect(event.reason).to be_nil
        expect(event.prerequisites_passed).to be true
      end

      it "resolves risk_level from the registry" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.risk_level).to eq("elevated")
      end

      it "includes the subject and capability" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.subject).to eq("service-account:introspection-agent")
        expect(event.capability).to eq("privileged_introspection")
      end

      it "converts prerequisites_checked to strings" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.prerequisites_checked).to eq(["file_exists"])
      end

      it "accepts optional session_id and context" do
        event = described_class.from_evaluation(
          result,
          registry: registry,
          session_id: "abc-123",
          context: { "env" => "test" }
        )

        expect(event.session_id).to eq("abc-123")
        expect(event.context).to eq({ "env" => "test" })
      end
    end

    context "with a denied result (not_granted)" do
      let(:result) do
        Wild::CapabilityGate::EvaluationResult.denied(
          capability_name: :privileged_introspection,
          caller_id: "service-account:unknown-agent",
          reason: :not_granted,
          details: "caller not granted",
          timestamp: timestamp
        )
      end

      it 'creates an event with outcome "deny"' do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.outcome).to eq("deny")
        expect(event.reason).to eq("not_granted")
      end

      it "sets prerequisites_passed to true (denial was not prerequisite-related)" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.prerequisites_passed).to be true
      end
    end

    context "with a denied result (prerequisite_not_met)" do
      let(:result) do
        Wild::CapabilityGate::EvaluationResult.denied(
          capability_name: :privileged_introspection,
          caller_id: "service-account:introspection-agent",
          reason: :prerequisite_not_met,
          details: "file not found",
          timestamp: timestamp
        )
      end

      it "sets prerequisites_passed to false" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.prerequisites_passed).to be false
      end
    end

    context "with a denied result (unknown_capability)" do
      let(:result) do
        Wild::CapabilityGate::EvaluationResult.denied(
          capability_name: :nonexistent,
          caller_id: "service-account:unknown-agent",
          reason: :unknown_capability,
          details: "not registered",
          timestamp: timestamp
        )
      end

      it 'sets risk_level to "unknown" when capability is not in registry' do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.risk_level).to eq("unknown")
      end
    end
  end

  describe "#to_h" do
    let(:result) do
      Wild::CapabilityGate::EvaluationResult.allowed(
        capability_name: :privileged_introspection,
        caller_id: "service-account:introspection-agent",
        prerequisites_checked: [:file_exists],
        timestamp: timestamp
      )
    end

    # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength -- schema conformance test validates all fields together
    it "produces a hash matching the audit_event.yml contract (wild-rvv.4.1.3)" do
      event = described_class.from_evaluation(
        result,
        registry: registry,
        session_id: "sess-001",
        context: { "env" => "test" }
      )
      h = event.to_h

      expect(h["timestamp"]).to eq("2026-03-17T12:00:00.000Z")
      expect(h["subject"]).to eq("service-account:introspection-agent")
      expect(h["capability"]).to eq("privileged_introspection")
      expect(h["risk_level"]).to eq("elevated")
      expect(h["outcome"]).to eq("allow")
      expect(h["reason"]).to be_nil
      expect(h["rationale"]).to eq("granted")
      expect(h["policy_version"]).to match(/\Acapabilities\.yml@sha256:[a-f0-9]{64}\z/)
      expect(h["decision_id"]).to match(/\A[0-9a-f-]{36}\z/)
      expect(h["prerequisites_checked"]).to eq(["file_exists"])
      expect(h["prerequisites_passed"]).to be true
      # session_id + arbitrary context are consumer-open: under `extra`, not top-level.
      expect(h["extra"]).to eq({ "session_id" => "sess-001", "context" => { "env" => "test" } })
      expect(h).not_to have_key("event")
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength

    it "formats timestamp as ISO 8601 UTC with milliseconds" do
      event = described_class.from_evaluation(result, registry: registry)
      h = event.to_h

      expect(h["timestamp"]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
    end
  end

  describe "immutability" do
    let(:result) do
      Wild::CapabilityGate::EvaluationResult.allowed(
        capability_name: :privileged_introspection,
        caller_id: "service-account:introspection-agent",
        timestamp: timestamp
      )
    end

    it "is frozen after creation" do
      event = described_class.from_evaluation(result, registry: registry)

      expect(event).to be_frozen
    end

    it "freezes prerequisites_checked" do
      event = described_class.from_evaluation(result, registry: registry)

      expect(event.prerequisites_checked).to be_frozen
    end

    it "freezes context" do
      event = described_class.from_evaluation(
        result, registry: registry, context: { "key" => "val" }
      )

      expect(event.context).to be_frozen
    end
  end

  describe ".coerce_context (f-l08 addendum items 4, 10, 11)" do
    it "passes a real Hash through unchanged (by value)" do
      expect(described_class.coerce_context({ "env" => "test" })).to eq({ "env" => "test" })
    end

    it "never returns the CALLER's own Hash object — dup'ing prevents the FrozenError trap" do
      caller_hash = { "env" => "test" }
      coerced = described_class.coerce_context(caller_hash)

      expect(coerced).to eq(caller_hash)
      expect(coerced).not_to equal(caller_hash)
      expect(caller_hash).not_to be_frozen # the caller's own Hash is never touched
    end

    it "returns {} for nil (matches Hash(nil) semantics)" do
      expect(described_class.coerce_context(nil)).to eq({})
    end

    it "degrades a String to a bounded, sanitized placeholder instead of raising" do
      expect(described_class.coerce_context("not-a-hash")).to eq({ raw: '"not-a-hash"' })
    end

    it "degrades ANY non-empty Array — Kernel#Hash raises TypeError for pairs-shaped arrays too" do
      expect(described_class.coerce_context(%w[x y])).to eq({ raw: "#<Array size=2>" })
      expect(described_class.coerce_context([%w[a 1], %w[b 2]])).to eq({ raw: "#<Array size=2>" })
    end

    it "degrades an object whose #to_hash raises" do
      hostile = Class.new { def to_hash = raise("boom") }.new
      expect(described_class.coerce_context(hostile)).to eq({ raw: "#<#{hostile.class}>" })
    end

    it "redacts a secret-shaped token instead of writing it verbatim (item 4)" do
      coerced = described_class.coerce_context("token=sk-live-abc123")
      expect(coerced[:raw]).to include("REDACTED")
      expect(coerced[:raw]).not_to include("sk-live-abc123")
    end

    it "does not call #inspect on a multi-megabyte String — slices before inspecting" do
      huge = "x" * 5_000_000
      expect { described_class.coerce_context(huge) }.not_to raise_error
      coerced = described_class.coerce_context(huge)
      expect(coerced[:raw].length).to be < 300
    end

    it "does not raise SystemStackError on a very deeply nested Array (never calls #inspect on it)" do
      deep = 20_000.times.inject([]) { |acc, _| [acc] }
      expect { described_class.coerce_context(deep) }.not_to raise_error
      expect(described_class.coerce_context(deep)).to eq({ raw: "#<Array size=1>" })
    end

    it "replaces a Hash context containing NaN with a bounded, diagnosable summary" do
      coerced = described_class.coerce_context({ "value" => Float::NAN, "other" => 1 })
      expect(coerced).to eq({ truncated: true, keys: %w[value other] })
    end

    it "replaces an oversized Hash context (over the 2 KiB extra budget) with a bounded summary" do
      big = { "blob" => "x" * 3000 }
      coerced = described_class.coerce_context(big)
      expect(coerced).to eq({ truncated: true, keys: ["blob"] })
    end

    it "keeps a small, JSON-safe Hash context exactly as given" do
      small = { "env" => "test", "count" => 3 }
      expect(described_class.coerce_context(small)).to eq(small)
    end
  end

  describe "context construction never re-freezes the caller's own Hash (f-l08 addendum item 4)" do
    it "does not raise FrozenError when the caller reuses the same context Hash for a second evaluation" do
      shared_context = { "env" => "test" }
      described_class.new(
        timestamp: timestamp, subject: "svc:a", capability: "basic_introspection",
        risk_level: "standard", outcome: "allow",
        policy_version: Wild::CapabilityGate::Registry::UNKNOWN_POLICY_VERSION,
        context: shared_context
      )

      expect(shared_context).not_to be_frozen
      expect { shared_context["env"] = "production" }.not_to raise_error
    end
  end

  describe "outcome normalization (never raises — runs inside the rescue path)" do
    # F2: Event construction happens inside Evaluator#evaluate's rescue handler.
    # A raise here would re-open the silent-denial hole. So an unrecognized
    # outcome collapses to the evaluation_error sentinel rather than raising —
    # a stray value can never produce an auditless denial. (wild-rvv.4.1.3,
    # Armstrong gate.)
    it "collapses an unrecognized outcome to evaluation_error instead of raising" do
      event = described_class.new(
        timestamp: timestamp, subject: "test", capability: "test",
        risk_level: "standard", outcome: "maybe",
        policy_version: Wild::CapabilityGate::Registry::UNKNOWN_POLICY_VERSION
      )
      expect(event.outcome).to eq("evaluation_error")
    end

    it "accepts the three contract outcomes verbatim" do
      %w[allow deny evaluation_error].each do |outcome|
        event = described_class.new(
          timestamp: timestamp, subject: "test", capability: "test",
          risk_level: "standard", outcome: outcome,
          policy_version: Wild::CapabilityGate::Registry::UNKNOWN_POLICY_VERSION
        )
        expect(event.outcome).to eq(outcome)
      end
    end
  end
end
