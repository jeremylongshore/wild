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

      it 'creates an event with result "allowed"' do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.result).to eq("allowed")
        expect(event.reason).to be_nil
        expect(event.prerequisites_passed).to be true
      end

      it "resolves risk_level from the registry" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.risk_level).to eq("elevated")
      end

      it "includes the caller_id and capability" do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.caller_id).to eq("service-account:introspection-agent")
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

      it 'creates an event with result "denied"' do
        event = described_class.from_evaluation(result, registry: registry)

        expect(event.result).to eq("denied")
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
    it "produces a hash matching Doc 002 Section 8 schema" do
      event = described_class.from_evaluation(
        result,
        registry: registry,
        session_id: "sess-001",
        context: { "env" => "test" }
      )
      h = event.to_h

      expect(h["event"]).to eq("capability_evaluation")
      expect(h["timestamp"]).to eq("2026-03-17T12:00:00.000Z")
      expect(h["caller_id"]).to eq("service-account:introspection-agent")
      expect(h["capability"]).to eq("privileged_introspection")
      expect(h["risk_level"]).to eq("elevated")
      expect(h["result"]).to eq("allowed")
      expect(h["reason"]).to be_nil
      expect(h["prerequisites_checked"]).to eq(["file_exists"])
      expect(h["prerequisites_passed"]).to be true
      expect(h["session_id"]).to eq("sess-001")
      expect(h["context"]).to eq({ "env" => "test" })
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

  describe "validation" do
    it "rejects invalid result values" do
      expect do
        described_class.new(
          timestamp: timestamp, caller_id: "test", capability: "test",
          risk_level: "standard", result: "maybe"
        )
      end.to raise_error(ArgumentError, /invalid result/)
    end
  end
end
