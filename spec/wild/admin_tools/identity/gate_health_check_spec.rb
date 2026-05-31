# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Identity::GateHealthCheck do
  let(:test_gate) { Wild::AdminTools::TestSupport::TestGate.new }
  let(:gate_client) { Wild::AdminTools::Identity::GateClient.new(gate: test_gate) }
  let(:health_check) { described_class.new(gate_client: gate_client) }

  describe "#check" do
    context "when gate is healthy" do
      it "returns healthy status" do
        result = health_check.check
        expect(result[:status]).to eq("healthy")
        expect(result[:gate_configured]).to be(true)
      end
    end

    context "when gate is not configured" do
      let(:gate_client) { Wild::AdminTools::Identity::GateClient.new(gate: nil) }

      it "returns unhealthy status" do
        result = health_check.check
        expect(result[:status]).to eq("unhealthy")
        expect(result[:gate_configured]).to be(false)
        expect(result[:reason]).to include("not configured")
      end
    end

    context "when gate raises an error" do
      let(:broken_gate) do
        Object.new.tap do |g|
          def g.evaluate(**_args)
            raise "gate crashed"
          end
        end
      end
      let(:gate_client) { Wild::AdminTools::Identity::GateClient.new(gate: broken_gate) }

      it "returns unhealthy status with error details" do
        result = health_check.check
        expect(result[:status]).to eq("unhealthy")
        expect(result[:reason]).to include("gate crashed")
      end
    end

    context "when gate denies the probe" do
      before { test_gate.default_result = false }

      it "still returns healthy (deny is a valid response)" do
        result = health_check.check
        expect(result[:status]).to eq("healthy")
      end
    end
  end
end
