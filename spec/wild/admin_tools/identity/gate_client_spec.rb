# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Identity::GateClient do
  let(:test_gate) { Wild::AdminTools::TestSupport::TestGate.new }
  let(:client) { described_class.new(gate: test_gate) }

  let(:session) do
    Wild::AdminTools::Identity::SessionContext.new(
      caller_id: "user_1",
      authenticated: true
    )
  end

  describe "#authorize" do
    context "when gate allows" do
      it "returns session with gate_result allowed" do
        result = client.authorize(session, "inspect_job")
        expect(result.gate_result).to eq("allowed")
      end

      it "includes the capability in capabilities" do
        result = client.authorize(session, "inspect_job")
        expect(result.capabilities).to include(:"admin_tools.inspect_job")
      end

      it "preserves caller_id and authenticated status" do
        result = client.authorize(session, "inspect_job")
        expect(result.caller_id).to eq("user_1")
        expect(result.authenticated).to be(true)
      end
    end

    context "when gate denies" do
      before { test_gate.default_result = false }

      it "returns session with gate_result denied" do
        result = client.authorize(session, "discard_job")
        expect(result.gate_result).to eq("denied")
      end

      it "returns empty capabilities" do
        result = client.authorize(session, "discard_job")
        expect(result.capabilities).to be_empty
      end
    end

    context "when gate denies a specific capability" do
      before { test_gate.deny_capability(:"admin_tools.delete_flag") }

      it "denies the specific capability" do
        result = client.authorize(session, "delete_flag")
        expect(result.gate_result).to eq("denied")
      end

      it "allows other capabilities" do
        result = client.authorize(session, "inspect_job")
        expect(result.gate_result).to eq("allowed")
      end
    end

    context "when gate is nil" do
      let(:client) { described_class.new(gate: nil) }

      it "raises GateError" do
        expect do
          client.authorize(session, "inspect_job")
        end.to raise_error(Wild::AdminTools::GateError, /not configured/)
      end
    end

    context "when gate raises an error" do
      let(:broken_gate) do
        Object.new.tap do |g|
          def g.evaluate(**_args)
            raise "gate exploded"
          end
        end
      end
      let(:client) { described_class.new(gate: broken_gate) }

      it "wraps the error in GateError" do
        expect do
          client.authorize(session, "inspect_job")
        end.to raise_error(Wild::AdminTools::GateError, /gate exploded/)
      end

      it "preserves the original error" do
        client.authorize(session, "inspect_job")
      rescue Wild::AdminTools::GateError => e
        expect(e.original_error).to be_a(RuntimeError)
      end
    end

    it "passes correct capability name to gate" do
      client.authorize(session, "retry_job")
      call = test_gate.calls.last
      expect(call[:capability]).to eq(:"admin_tools.retry_job")
    end

    it "passes caller to gate" do
      client.authorize(session, "retry_job")
      call = test_gate.calls.last
      expect(call[:caller]).to eq("user_1")
    end
  end

  describe "#configured?" do
    it "returns true when gate is present" do
      expect(client).to be_configured
    end

    it "returns false when gate is nil" do
      nil_client = described_class.new(gate: nil)
      expect(nil_client).not_to be_configured
    end
  end
end
