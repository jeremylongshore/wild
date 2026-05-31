# frozen_string_literal: true

require "tmpdir"

RSpec.describe Wild::Introspection::Audit::Recorder do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:log_dir) { Dir.mktmpdir }
  let(:log_path) { File.join(log_dir, "audit.jsonl") }
  let(:ctx) { authenticated_context }

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
    Wild::Introspection.configuration.audit_log_path = log_path
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    account
    user
  end

  after { FileUtils.rm_rf(log_dir) }

  def audit_entries
    File.readlines(log_path).map { |line| JSON.parse(line) }
  end

  def last_audit_entry
    audit_entries.last
  end

  describe "inspect_schema" do
    it "produces an audit record with outcome=success for allowed model" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("success")
      expect(entry["guard_result"]).to eq("allowed")
      expect(entry["tool_name"]).to eq("inspect_model_schema")
      expect(entry["model_name"]).to eq("Account")
    end

    it "produces an audit record with outcome=denied for blocked model" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("CreditCard", request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("denied")
      expect(entry["guard_result"]).to eq("denied_model_not_allowed")
    end

    it "produces an audit record with outcome=denied for unknown model" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("FakeModel", request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("denied")
      expect(entry["guard_result"]).to eq("denied_model_not_allowed")
    end

    it "does not leak model existence in audit records" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("CreditCard", request_context: ctx)
      blocked_entry = last_audit_entry

      Wild::Introspection::Guard::QueryGuard.inspect_schema("FakeModel", request_context: ctx)
      unknown_entry = last_audit_entry

      expect(blocked_entry["outcome"]).to eq(unknown_entry["outcome"])
      expect(blocked_entry["guard_result"]).to eq(unknown_entry["guard_result"])
      expect(blocked_entry["rows_returned"]).to eq(unknown_entry["rows_returned"])
    end
  end

  describe "find_by_id" do
    it "produces an audit record with rows_returned=1 for found record" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", account.id, request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("success")
      expect(entry["guard_result"]).to eq("allowed")
      expect(entry["rows_returned"]).to eq(1)
      expect(entry["tool_name"]).to eq("lookup_record_by_id")
    end

    it "produces an audit record with rows_returned=0 for not_found" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", 99_999, request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("success")
      expect(entry["guard_result"]).to eq("allowed")
      expect(entry["rows_returned"]).to eq(0)
    end

    it "produces denial audit record for blocked model" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("CreditCard", 1, request_context: ctx)

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("denied")
      expect(entry["rows_returned"]).to eq(0)
    end

    it "includes id in sanitized parameters" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", account.id, request_context: ctx)

      entry = last_audit_entry
      expect(entry["parameters"]["fields"]["id"]).to eq(account.id)
    end
  end

  describe "find_by_filter" do
    it "produces an audit record with correct row count" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "slug", value: "acme", request_context: ctx
      )

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("success")
      expect(entry["guard_result"]).to eq("allowed")
      expect(entry["rows_returned"]).to eq(1)
      expect(entry["tool_name"]).to eq("find_records_by_filter")
    end

    it "produces denial audit record for blocked filter field" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "stripe_customer_id", value: "cus_secret123", request_context: ctx
      )

      entry = last_audit_entry
      expect(entry["outcome"]).to eq("denied")
    end

    it "redacts blocked column values in audit parameters" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "stripe_customer_id", value: "cus_secret123", request_context: ctx
      )

      entry = last_audit_entry
      expect(entry["parameters"]["fields"]["value"]).to eq("[REDACTED]")
      expect(entry.to_s).not_to include("cus_secret123")
    end

    it "includes field and value for safe filter fields" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "slug", value: "acme", request_context: ctx
      )

      entry = last_audit_entry
      expect(entry["parameters"]["fields"]["field"]).to eq("slug")
      expect(entry["parameters"]["fields"]["value"]).to eq("acme")
    end
  end

  describe "identity in audit records" do
    it "records authenticated caller identity" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      entry = last_audit_entry
      expect(entry["caller_id"]).to eq("test-agent")
      expect(entry["caller_type"]).to eq("api_key")
    end

    it "records anonymous identity for unauthenticated calls" do
      anon_ctx = anonymous_context
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: anon_ctx)

      entry = last_audit_entry
      expect(entry["caller_id"]).to eq("anonymous")
      expect(entry["caller_type"]).to eq("unknown")
    end
  end

  describe "common audit record properties" do
    it "populates duration_ms >= 0" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      entry = last_audit_entry
      expect(entry["duration_ms"]).to be >= 0
    end

    it "includes all required fields in every audit record" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      entry = last_audit_entry
      Wild::Introspection::Audit::AuditRecord::FIELDS.each do |field|
        expect(entry).to have_key(field.to_s), "expected audit entry to include #{field}"
      end
    end

    it "includes server_version" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      entry = last_audit_entry
      expect(entry["server_version"]).to eq(Wild::VERSION)
    end

    it "returns the original guard result unchanged" do
      result = Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)

      expect(result[:status]).to eq(:ok)
      expect(result[:columns]).to be_an(Array)
    end

    it "returns the original denial result unchanged" do
      result = Wild::Introspection::Guard::QueryGuard.inspect_schema("CreditCard", request_context: ctx)

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:model_not_allowed)
    end
  end

  describe "every guard path produces exactly one audit record" do
    it "inspect_schema success produces one record" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: ctx)
      expect(audit_entries.size).to eq(1)
    end

    it "inspect_schema denial produces one record" do
      Wild::Introspection::Guard::QueryGuard.inspect_schema("CreditCard", request_context: ctx)
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_id success produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", account.id, request_context: ctx)
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_id not_found produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", 99_999, request_context: ctx)
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_id denial produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("CreditCard", 1, request_context: ctx)
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_filter success produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "slug", value: "acme", request_context: ctx
      )
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_filter denied field produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "Account", field: "stripe_customer_id", value: "x", request_context: ctx
      )
      expect(audit_entries.size).to eq(1)
    end

    it "find_by_filter denied model produces one record" do
      Wild::Introspection::Guard::QueryGuard.find_by_filter(
        "CreditCard", field: "number", value: "x", request_context: ctx
      )
      expect(audit_entries.size).to eq(1)
    end

    it "auth denial produces one record" do
      anon_ctx = anonymous_context
      Wild::Introspection::Guard::QueryGuard.inspect_schema("Account", request_context: anon_ctx)
      expect(audit_entries.size).to eq(1)
    end
  end

  describe "full record contents never logged" do
    it "audit record does not contain actual record data" do
      Wild::Introspection::Guard::QueryGuard.find_by_id("Account", account.id, request_context: ctx)

      raw = File.read(log_path)
      expect(raw).not_to include("Acme Corp")
      expect(raw).not_to include("cus_secret123")
      expect(raw).not_to include("tax_secret456")
    end
  end
end
