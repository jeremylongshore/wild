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
