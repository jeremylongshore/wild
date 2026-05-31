# frozen_string_literal: true

RSpec.describe Wild::Introspection::Identity::CapabilityGate do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".permitted?" do
    context "with an authenticated caller" do
      let(:ctx) { authenticated_context }

      it "permits all actions in v1" do
        described_class::ACTIONS.each do |action|
          expect(described_class.permitted?(ctx, action: action, resource: "Account")).to be(true)
        end
      end

      it "permits actions without a resource" do
        expect(described_class.permitted?(ctx, action: "inspect_model_schema")).to be(true)
      end
    end

    context "with an anonymous caller" do
      let(:ctx) { anonymous_context }

      it "denies all actions" do
        described_class::ACTIONS.each do |action|
          expect(described_class.permitted?(ctx, action: action, resource: "Account")).to be(false)
        end
      end
    end

    context "with an invalid-auth caller" do
      let(:ctx) do
        Wild::Introspection::Identity::RequestContext.new(
          caller_id: "unknown", caller_type: "api_key", auth_result: :invalid
        )
      end

      it "denies all actions" do
        expect(described_class.permitted?(ctx, action: "inspect_model_schema")).to be(false)
      end
    end
  end

  describe ".denial_response" do
    it "returns a frozen denial hash" do
      response = described_class.denial_response

      expect(response[:status]).to eq(:denied)
      expect(response[:reason]).to eq(:insufficient_capability)
      expect(response).to be_frozen
    end

    it "does not reveal internal details" do
      response = described_class.denial_response

      expect(response[:message]).not_to include("gate")
      expect(response[:message]).not_to include("wild")
    end
  end

  describe "ACTIONS" do
    it "lists the v1 tool actions" do
      expect(described_class::ACTIONS).to include(
        "inspect_model_schema",
        "lookup_record_by_id",
        "find_records_by_filter"
      )
    end
  end
end
