# frozen_string_literal: true

RSpec.describe Wild::Introspection::Server::Tools::LookupRecordById do
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
      expect(described_class.name_value).to eq("lookup_record_by_id")
    end

    it "has a description" do
      expect(described_class.description_value).to be_a(String)
      expect(described_class.description_value).not_to be_empty
    end

    it "requires model_name and id as input" do
      schema = described_class.input_schema_value
      expect(schema.to_h[:required]).to include("model_name", "id")
    end

    it "declares read_only annotations" do
      annotations = described_class.annotations_value
      expect(annotations.to_h[:readOnlyHint]).to be(true)
      expect(annotations.to_h[:destructiveHint]).to be(false)
    end
  end

  describe ".call" do
    context "with a found record" do
      it "returns the record with blocked columns stripped" do
        response = described_class.call(
          model_name: "Account", id: account.id.to_s,
          server_context: authenticated_server_context
        )

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("ok")
        expect(parsed[:record].keys.map(&:to_s)).to include("id", "name", "slug")
        expect(parsed[:record].keys.map(&:to_s)).not_to include("stripe_customer_id", "tax_id", "ssn")
      end
    end

    context "with a nonexistent record" do
      it "returns not_found with error: false" do
        response = described_class.call(
          model_name: "Account", id: "99999",
          server_context: authenticated_server_context
        )

        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("not_found")
      end
    end

    context "with a denied model" do
      it "returns an error response" do
        response = described_class.call(
          model_name: "CreditCard", id: "1",
          server_context: authenticated_server_context
        )

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "with nil server_context (auth failure)" do
      it "returns an error response for gate denial" do
        response = described_class.call(model_name: "Account", id: "1", server_context: nil)

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end
end
