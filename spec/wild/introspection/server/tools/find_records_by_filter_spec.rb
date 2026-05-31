# frozen_string_literal: true

RSpec.describe Wild::Introspection::Server::Tools::FindRecordsByFilter do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:account) do
    Account.create!(
      name: "Acme Corp", slug: "acme", plan: "pro",
      stripe_customer_id: "cus_secret123", tax_id: "tax_secret456", ssn: "999-99-9999"
    )
  end

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    account
  end

  describe "MCP metadata" do
    it "has the correct tool_name" do
      expect(described_class.name_value).to eq("find_records_by_filter")
    end

    it "has a description" do
      expect(described_class.description_value).to be_a(String)
      expect(described_class.description_value).not_to be_empty
    end

    it "requires model_name, field, and value as input" do
      schema = described_class.input_schema_value
      expect(schema.to_h[:required]).to include("model_name", "field", "value")
    end

    it "declares read_only annotations" do
      annotations = described_class.annotations_value
      expect(annotations.to_h[:readOnlyHint]).to be(true)
      expect(annotations.to_h[:destructiveHint]).to be(false)
    end
  end

  describe ".call" do
    context "with matching records" do
      it "returns filtered records with correct count" do
        response = described_class.call(
          model_name: "Account", field: "slug", value: "acme",
          server_context: authenticated_server_context
        )

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("ok")
        expect(parsed[:records]).to be_an(Array)
        expect(parsed[:records].size).to eq(1)
      end

      it "strips blocked columns from results" do
        response = described_class.call(
          model_name: "Account", field: "slug", value: "acme",
          server_context: authenticated_server_context
        )

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        parsed[:records].each do |record|
          expect(record.keys.map(&:to_s)).not_to include("stripe_customer_id", "tax_id", "ssn")
        end
      end
    end

    context "with a blocked filter field" do
      it "returns an error response" do
        response = described_class.call(
          model_name: "Account", field: "stripe_customer_id", value: "cus_secret123",
          server_context: authenticated_server_context
        )

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "with a denied model" do
      it "returns an error response" do
        response = described_class.call(
          model_name: "CreditCard", field: "number", value: "1234",
          server_context: authenticated_server_context
        )

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "with nil server_context (auth failure)" do
      it "returns an error response for gate denial" do
        response = described_class.call(
          model_name: "Account", field: "slug", value: "acme",
          server_context: nil
        )

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end
end
