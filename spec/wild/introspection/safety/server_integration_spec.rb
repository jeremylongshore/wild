# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Integration tests for Epic 7 (beads 869.6)
#
# These tests simulate an AI agent connecting to the server, discovering tools,
# calling each tool, and receiving correct responses including denials and errors.
# All tests use real pipeline integration — no mocked layers.
RSpec.describe "MCP Server Integration", :integration do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:server) { Wild::Introspection::Server::ServerFactory.create(server_context: server_context) }
  let(:server_context) { authenticated_server_context }

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

  # Helper: call a tool through the server's tool registry, exactly as the MCP
  # protocol would. The server passes server_context to tool.call automatically.
  def call_tool(tool_name, **arguments)
    tool = server.tools[tool_name]
    raise "Tool '#{tool_name}' not found" unless tool

    tool.call(**arguments, server_context: server.server_context)
  end

  def parse_response(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  # -------------------------------------------------------------------
  # Scenario 1: Agent discovers all three tools
  # -------------------------------------------------------------------
  describe "tool discovery" do
    it "server exposes exactly three tools" do
      expect(server.tools.size).to eq(3)
    end

    it "tool names match the v1 tool set" do
      expect(server.tools.keys).to contain_exactly(
        "inspect_model_schema",
        "lookup_record_by_id",
        "find_records_by_filter"
      )
    end

    it "each tool has a description and input schema" do
      server.tools.each_value do |tool|
        expect(tool.description_value).to be_a(String)
        expect(tool.description_value).not_to be_empty
        expect(tool.input_schema_value).not_to be_nil
      end
    end

    it "each tool declares read-only annotations" do
      server.tools.each_value do |tool|
        annotations = tool.annotations_value.to_h
        expect(annotations[:readOnlyHint]).to be(true)
        expect(annotations[:destructiveHint]).to be(false)
      end
    end
  end

  # -------------------------------------------------------------------
  # Scenario 2: inspect_model_schema — allowed model
  # -------------------------------------------------------------------
  describe "inspect_model_schema with allowed model" do
    it "returns schema with columns and associations" do
      response = call_tool("inspect_model_schema", model_name: "Account")
      parsed = parse_response(response)

      expect(response.error?).to be(false)
      expect(parsed[:status]).to eq("ok")
      expect(parsed[:columns]).to be_an(Array)
      expect(parsed[:columns].size).to be > 0
      expect(parsed[:associations]).to be_an(Array)
    end

    it "includes only accessible columns" do
      response = call_tool("inspect_model_schema", model_name: "Account")
      col_names = parse_response(response)[:columns].pluck(:name)

      expect(col_names).to include("id", "name", "slug", "plan")
      expect(col_names).not_to include("stripe_customer_id", "tax_id", "ssn")
    end
  end

  # -------------------------------------------------------------------
  # Scenario 3: inspect_model_schema — blocked model → denial
  # -------------------------------------------------------------------
  describe "inspect_model_schema with blocked model" do
    it "returns a denial and does not leak model existence" do
      response = call_tool("inspect_model_schema", model_name: "CreditCard")
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
      expect(parsed[:message]).not_to include("CreditCard")
    end
  end

  # -------------------------------------------------------------------
  # Scenario 4: lookup_record_by_id — existing record
  # -------------------------------------------------------------------
  describe "lookup_record_by_id with existing record" do
    it "returns the record with blocked columns stripped" do
      response = call_tool("lookup_record_by_id", model_name: "Account", id: account.id.to_s)
      parsed = parse_response(response)

      expect(response.error?).to be(false)
      expect(parsed[:status]).to eq("ok")
      expect(parsed[:record].keys.map(&:to_s)).to include("id", "name", "slug")
      expect(parsed[:record].keys.map(&:to_s)).not_to include("stripe_customer_id", "tax_id", "ssn")
    end

    it "returns correct record values" do
      response = call_tool("lookup_record_by_id", model_name: "Account", id: account.id.to_s)
      record = parse_response(response)[:record]

      expect(record[:name]).to eq("Acme Corp")
      expect(record[:slug]).to eq("acme")
    end
  end

  # -------------------------------------------------------------------
  # Scenario 5: lookup_record_by_id — nonexistent record
  # -------------------------------------------------------------------
  describe "lookup_record_by_id with nonexistent record" do
    it "returns not_found (not an error)" do
      response = call_tool("lookup_record_by_id", model_name: "Account", id: "99999")
      parsed = parse_response(response)

      expect(response.error?).to be(false)
      expect(parsed[:status]).to eq("not_found")
    end
  end

  # -------------------------------------------------------------------
  # Scenario 6: find_records_by_filter — matching records
  # -------------------------------------------------------------------
  describe "find_records_by_filter with matching records" do
    it "returns filtered results" do
      response = call_tool("find_records_by_filter",
                           model_name: "Account", field: "slug", value: "acme")
      parsed = parse_response(response)

      expect(response.error?).to be(false)
      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_an(Array)
      expect(parsed[:records].size).to eq(1)
      expect(parsed[:records].first[:name]).to eq("Acme Corp")
    end

    it "strips blocked columns from filtered results" do
      response = call_tool("find_records_by_filter",
                           model_name: "Account", field: "slug", value: "acme")
      parsed = parse_response(response)

      parsed[:records].each do |record|
        expect(record.keys.map(&:to_s)).not_to include("stripe_customer_id", "tax_id", "ssn")
      end
    end
  end

  # -------------------------------------------------------------------
  # Scenario 7: Unauthenticated call → rejected
  # -------------------------------------------------------------------
  describe "unauthenticated invocation" do
    let(:server_context) { nil }

    it "rejects inspect_model_schema" do
      response = call_tool("inspect_model_schema", model_name: "Account")
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "rejects lookup_record_by_id" do
      response = call_tool("lookup_record_by_id", model_name: "Account", id: "1")
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "rejects find_records_by_filter" do
      response = call_tool("find_records_by_filter",
                           model_name: "Account", field: "slug", value: "acme")
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "does not reveal model existence to unauthenticated callers" do
      allowed = call_tool("inspect_model_schema", model_name: "Account")
      blocked = call_tool("inspect_model_schema", model_name: "CreditCard")
      unknown = call_tool("inspect_model_schema", model_name: "FakeModel")

      # All three should get the same gate denial shape
      allowed_parsed = parse_response(allowed)
      blocked_parsed = parse_response(blocked)
      unknown_parsed = parse_response(unknown)

      expect(allowed_parsed[:reason]).to eq(blocked_parsed[:reason])
      expect(blocked_parsed[:reason]).to eq(unknown_parsed[:reason])
    end
  end

  # -------------------------------------------------------------------
  # Scenario 8: Every call produces a correct audit record
  # -------------------------------------------------------------------
  describe "audit trail completeness" do
    let(:audit_records) { [] }

    before do
      allow(Wild::Introspection::Audit::AuditLogger).to receive(:log) do |record|
        audit_records << record
      end
    end

    it "produces an audit record for successful inspect_model_schema" do
      call_tool("inspect_model_schema", model_name: "Account")

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.tool_name).to eq("inspect_model_schema")
      expect(audit_records.first.outcome).to eq("success")
      expect(audit_records.first.caller_id).to eq("test-agent")
    end

    it "produces an audit record for denied inspect_model_schema" do
      call_tool("inspect_model_schema", model_name: "CreditCard")

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("denied")
    end

    it "produces an audit record for successful lookup_record_by_id" do
      call_tool("lookup_record_by_id", model_name: "Account", id: account.id.to_s)

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.tool_name).to eq("lookup_record_by_id")
      expect(audit_records.first.outcome).to eq("success")
      expect(audit_records.first.rows_returned).to eq(1)
    end

    it "produces an audit record for not_found lookup" do
      call_tool("lookup_record_by_id", model_name: "Account", id: "99999")

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("success")
      expect(audit_records.first.rows_returned).to eq(0)
    end

    it "produces an audit record for successful find_records_by_filter" do
      call_tool("find_records_by_filter",
                model_name: "Account", field: "slug", value: "acme")

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.tool_name).to eq("find_records_by_filter")
      expect(audit_records.first.outcome).to eq("success")
      expect(audit_records.first.rows_returned).to eq(1)
    end

    it "produces an audit record for blocked filter field" do
      call_tool("find_records_by_filter",
                model_name: "Account", field: "stripe_customer_id", value: "x")

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("denied")
    end

    context "with unauthenticated caller" do
      let(:server_context) { nil }

      it "produces an audit record for gate denial" do
        call_tool("inspect_model_schema", model_name: "Account")

        expect(audit_records.size).to eq(1)
        expect(audit_records.first.outcome).to eq("denied")
        expect(audit_records.first.caller_id).to eq("anonymous")
      end

      it "produces exactly one audit record per invocation, not zero" do
        call_tool("lookup_record_by_id", model_name: "Account", id: "1")
        call_tool("find_records_by_filter",
                  model_name: "Account", field: "slug", value: "x")

        expect(audit_records.size).to eq(2)
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
