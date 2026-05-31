# frozen_string_literal: true

RSpec.describe Wild::Introspection::Server::Tools::InspectModelSchema do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe "MCP metadata" do
    it "has the correct tool_name" do
      expect(described_class.name_value).to eq("inspect_model_schema")
    end

    it "has a description" do
      expect(described_class.description_value).to be_a(String)
      expect(described_class.description_value).not_to be_empty
    end

    it "requires model_name as input" do
      schema = described_class.input_schema_value
      expect(schema.to_h[:required]).to include("model_name")
    end

    it "declares read_only annotations" do
      annotations = described_class.annotations_value
      expect(annotations.to_h[:readOnlyHint]).to be(true)
      expect(annotations.to_h[:destructiveHint]).to be(false)
    end
  end

  describe ".call" do
    context "with an allowed model" do
      it "returns schema with columns and associations" do
        response = described_class.call(model_name: "Account", server_context: authenticated_server_context)

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("ok")
        expect(parsed[:columns]).to be_an(Array)
      end

      it "strips blocked columns from the response" do
        response = described_class.call(model_name: "Account", server_context: authenticated_server_context)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        col_names = parsed[:columns].pluck(:name)
        expect(col_names).not_to include("stripe_customer_id", "tax_id", "ssn")
      end
    end

    context "with a denied model" do
      it "returns an error response" do
        response = described_class.call(model_name: "CreditCard", server_context: authenticated_server_context)

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "with nil server_context (auth failure)" do
      it "returns an error response for gate denial" do
        response = described_class.call(model_name: "Account", server_context: nil)

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end
end
