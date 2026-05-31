# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Server-edge safety tests — hardening the MCP tool boundary.
#
# These tests verify safety invariants at the server/tool layer,
# complementing the lower-level guard/adapter/audit specs.
# Every test uses real pipeline integration.
RSpec.describe "Server Edge Safety", :safety do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:account) do
    Account.create!(
      name: "Acme Corp", slug: "acme", plan: "pro",
      stripe_customer_id: "cus_secret123", tax_id: "tax_secret456", ssn: "999-99-9999"
    )
  end

  let(:user) do
    User.create!(
      account: account, email: "alice@acme.com", name: "Alice", status: "active",
      password_digest: "hashed_pw", otp_secret: "totp_key", credit_card_number: "4111111111111111"
    )
  end

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    account
    user
  end

  def parse_response(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  # -------------------------------------------------------------------
  # Safety invariant: blocked columns never appear in MCP tool responses
  # -------------------------------------------------------------------
  describe "blocked columns never appear in tool responses" do
    let(:blocked_columns) { %w[stripe_customer_id tax_id ssn] }
    let(:ctx) { authenticated_server_context }

    it "strips blocked columns from inspect_model_schema" do
      tool = Wild::Introspection::Server::Tools::InspectModelSchema
      response = tool.call(model_name: "Account", server_context: ctx)
      col_names = parse_response(response)[:columns].pluck(:name)

      expect(col_names & blocked_columns).to be_empty
    end

    it "strips blocked columns from lookup_record_by_id" do
      tool = Wild::Introspection::Server::Tools::LookupRecordById
      response = tool.call(model_name: "Account", id: account.id.to_s, server_context: ctx)
      record_keys = parse_response(response)[:record].keys.map(&:to_s)

      expect(record_keys & blocked_columns).to be_empty
    end

    it "strips blocked columns from find_records_by_filter" do
      tool = Wild::Introspection::Server::Tools::FindRecordsByFilter
      response = tool.call(model_name: "Account", field: "slug", value: "acme", server_context: ctx)
      parsed = parse_response(response)

      parsed[:records].each do |record|
        expect(record.keys.map(&:to_s) & blocked_columns).to be_empty
      end
    end

    it "strips User-specific blocked columns from lookup_record_by_id" do
      tool = Wild::Introspection::Server::Tools::LookupRecordById
      response = tool.call(model_name: "User", id: user.id.to_s, server_context: ctx)
      record_keys = parse_response(response)[:record].keys.map(&:to_s)

      expect(record_keys).not_to include("password_digest", "otp_secret", "credit_card_number")
    end

    it "strips blocked column values from response content" do
      tool = Wild::Introspection::Server::Tools::LookupRecordById
      response = tool.call(model_name: "Account", id: account.id.to_s, server_context: ctx)
      raw_text = response.content.first[:text]

      expect(raw_text).not_to include("cus_secret123")
      expect(raw_text).not_to include("tax_secret456")
      expect(raw_text).not_to include("999-99-9999")
    end
  end

  # -------------------------------------------------------------------
  # Safety invariant: every invocation produces exactly one audit record
  # -------------------------------------------------------------------
  describe "every tool invocation produces exactly one audit record" do
    let(:audit_records) { [] }

    before do
      allow(Wild::Introspection::Audit::AuditLogger).to receive(:log) do |record|
        audit_records << record
      end
    end

    def call_and_count(tool_class, **args)
      audit_records.clear
      tool_class.call(**args, server_context: authenticated_server_context)
      audit_records.size
    end

    it "one record for successful schema inspection" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::InspectModelSchema,
               model_name: "Account"
             )).to eq(1)
    end

    it "one record for denied schema inspection" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::InspectModelSchema,
               model_name: "CreditCard"
             )).to eq(1)
    end

    it "one record for successful record lookup" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::LookupRecordById,
               model_name: "Account", id: account.id.to_s
             )).to eq(1)
    end

    it "one record for not_found record lookup" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::LookupRecordById,
               model_name: "Account", id: "99999"
             )).to eq(1)
    end

    it "one record for successful filter" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::FindRecordsByFilter,
               model_name: "Account", field: "slug", value: "acme"
             )).to eq(1)
    end

    it "one record for denied filter field" do
      expect(call_and_count(
               Wild::Introspection::Server::Tools::FindRecordsByFilter,
               model_name: "Account", field: "stripe_customer_id", value: "x"
             )).to eq(1)
    end

    it "one record for gate denial (nil server_context)" do
      audit_records.clear
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: nil
      )
      expect(audit_records.size).to eq(1)
    end

    it "one record for gate denial (invalid API key)" do
      audit_records.clear
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: { api_key: "sk-invalid-key" }
      )
      expect(audit_records.size).to eq(1)
    end
  end

  # -------------------------------------------------------------------
  # Safety invariant: gate denial does not leak model existence
  # -------------------------------------------------------------------
  describe "gate denial does not leak model existence" do
    it "returns identical response shape for allowed, blocked, and unknown models" do
      tool = Wild::Introspection::Server::Tools::InspectModelSchema

      allowed = parse_response(tool.call(model_name: "Account", server_context: nil))
      blocked = parse_response(tool.call(model_name: "CreditCard", server_context: nil))
      unknown = parse_response(tool.call(model_name: "FakeModel", server_context: nil))

      expect(allowed.keys.sort).to eq(blocked.keys.sort)
      expect(blocked.keys.sort).to eq(unknown.keys.sort)
      expect(allowed[:reason]).to eq(blocked[:reason])
      expect(blocked[:reason]).to eq(unknown[:reason])
    end

    it "uses the same denial reason for all gate denials across tools" do
      denials = [
        Wild::Introspection::Server::Tools::InspectModelSchema.call(
          model_name: "Account", server_context: nil
        ),
        Wild::Introspection::Server::Tools::LookupRecordById.call(
          model_name: "Account", id: "1", server_context: nil
        ),
        Wild::Introspection::Server::Tools::FindRecordsByFilter.call(
          model_name: "Account", field: "slug", value: "x", server_context: nil
        )
      ].map { |r| parse_response(r)[:reason] }

      expect(denials.uniq.size).to eq(1)
    end
  end

  # -------------------------------------------------------------------
  # Response format consistency: all responses are valid JSON text content
  # -------------------------------------------------------------------
  describe "response format consistency" do
    let(:ctx) { authenticated_server_context }

    def verify_mcp_response_format(response)
      expect(response).to be_a(MCP::Tool::Response)
      content = response.content
      expect(content.size).to eq(1)
      expect(content.first[:type]).to eq("text")
    end

    it "formats success responses correctly" do
      response = Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: ctx
      )
      verify_mcp_response_format(response)
      expect(response.error?).to be(false)
    end

    it "formats model denial responses correctly" do
      response = Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "CreditCard", server_context: ctx
      )
      verify_mcp_response_format(response)
      expect(response.error?).to be(true)
    end

    it "formats not_found responses correctly" do
      response = Wild::Introspection::Server::Tools::LookupRecordById.call(
        model_name: "Account", id: "99999", server_context: ctx
      )
      verify_mcp_response_format(response)
      expect(response.error?).to be(false)
    end

    it "formats gate denial responses correctly" do
      response = Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: nil
      )
      verify_mcp_response_format(response)
      expect(response.error?).to be(true)
    end

    it "formats filter denial responses correctly" do
      response = Wild::Introspection::Server::Tools::FindRecordsByFilter.call(
        model_name: "Account", field: "stripe_customer_id", value: "x",
        server_context: ctx
      )
      verify_mcp_response_format(response)
      expect(response.error?).to be(true)
    end
  end

  # -------------------------------------------------------------------
  # Structural invariant: all tools delegate through ToolHandler
  # -------------------------------------------------------------------
  describe "all tools delegate through ToolHandler" do
    before do
      allow(Wild::Introspection::Server::ToolHandler).to receive(:execute).and_call_original
    end

    it "ToolHandler.execute is called for every tool invocation" do
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: authenticated_server_context
      )
      Wild::Introspection::Server::Tools::LookupRecordById.call(
        model_name: "Account", id: "1", server_context: authenticated_server_context
      )
      Wild::Introspection::Server::Tools::FindRecordsByFilter.call(
        model_name: "Account", field: "slug", value: "x", server_context: authenticated_server_context
      )

      expect(Wild::Introspection::Server::ToolHandler).to have_received(:execute).exactly(3).times
    end
  end

  # -------------------------------------------------------------------
  # ServerFactory invariant: frozen, explicit tool set
  # -------------------------------------------------------------------
  describe "ServerFactory tool set invariant" do
    it "TOOLS constant is frozen and contains exactly 3 MCP::Tool subclasses" do
      tools = Wild::Introspection::Server::ServerFactory::TOOLS
      expect(tools).to be_frozen
      expect(tools.size).to eq(3)
      expect(tools).to all(be < MCP::Tool)
    end

    it "cannot be modified at runtime" do
      tools = Wild::Introspection::Server::ServerFactory::TOOLS
      expect { tools << Class.new(MCP::Tool) }.to raise_error(FrozenError)
    end
  end

  # -------------------------------------------------------------------
  # Audit identity attribution: caller identity in every audit record
  # -------------------------------------------------------------------
  describe "audit identity attribution" do
    let(:audit_records) { [] }

    before do
      allow(Wild::Introspection::Audit::AuditLogger).to receive(:log) do |record|
        audit_records << record
      end
    end

    it "records authenticated caller identity" do
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: authenticated_server_context
      )

      expect(audit_records.first.caller_id).to eq("test-agent")
      expect(audit_records.first.caller_type).to eq("api_key")
    end

    it "records anonymous identity for nil server_context" do
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: nil
      )

      expect(audit_records.first.caller_id).to eq("anonymous")
      expect(audit_records.first.caller_type).to eq("unknown")
    end

    it "records unknown identity for invalid API key" do
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: { api_key: "sk-bogus" }
      )

      expect(audit_records.first.caller_id).to eq("unknown")
      expect(audit_records.first.caller_type).to eq("api_key")
    end

    it "records empty-key caller as anonymous" do
      Wild::Introspection::Server::Tools::InspectModelSchema.call(
        model_name: "Account", server_context: { api_key: "" }
      )

      expect(audit_records.first.caller_id).to eq("anonymous")
    end
  end
end

# rubocop:enable RSpec/DescribeClass
