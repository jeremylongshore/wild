# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::EvaluationResult do
  describe ".allowed" do
    subject(:result) do
      described_class.allowed(
        capability_name: :basic_introspection,
        caller_id: "service-account:test"
      )
    end

    it "is allowed" do
      expect(result).to be_allowed
      expect(result).not_to be_denied
    end

    it "carries capability and caller info" do
      expect(result.capability_name).to eq(:basic_introspection)
      expect(result.caller_id).to eq("service-account:test")
    end

    it "has no denial reason" do
      expect(result.reason).to be_nil
      expect(result.details).to be_nil
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe ".denied" do
    subject(:result) do
      described_class.denied(
        capability_name: :admin_tools,
        caller_id: "unknown-caller",
        reason: :not_granted,
        details: "caller not in grant config"
      )
    end

    it "is denied" do
      expect(result).to be_denied
      expect(result).not_to be_allowed
    end

    it "carries the denial reason" do
      expect(result.reason).to eq(:not_granted)
      expect(result.details).to eq("caller not in grant config")
    end

    it "is frozen" do
      expect(result).to be_frozen
    end
  end
end
