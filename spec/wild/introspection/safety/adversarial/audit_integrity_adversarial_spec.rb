# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Adversarial tests for audit integrity and auth bypass.
#
# Safety claims covered: 6.8, 6.9, 7.7, 7.8, 7.9, 7.25, 9.1
# These tests verify that authentication cannot be bypassed via forged context,
# audit records are always produced (even under errors), and conservative defaults hold.
RSpec.describe "Audit Integrity Adversarial", :adversarial, :safety do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    Account.create!(
      name: "Acme Corp", slug: "acme", plan: "pro",
      stripe_customer_id: "cus_secret", tax_id: "tax_secret", ssn: "999-99-9999"
    )
  end

  let(:tool_schema) { Wild::Introspection::Server::Tools::InspectModelSchema }
  let(:tool_lookup) { Wild::Introspection::Server::Tools::LookupRecordById }

  def parse_response(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  # -------------------------------------------------------------------
  # Auth bypass via forged server_context — Claim 6.8, 6.9
  # -------------------------------------------------------------------
  describe "auth bypass via forged server_context" do
    it 'ignores extra "admin: true" key in server_context' do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: Wild::Introspection::TestSupport::TestConfigHelper::TEST_API_KEY, admin: true }
      )
      parsed = parse_response(response)

      # Normal auth succeeds; extra keys are silently ignored
      expect(parsed[:status]).to eq("ok")
    end

    it 'ignores extra "bypass_gate: true" key in server_context' do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: Wild::Introspection::TestSupport::TestConfigHelper::TEST_API_KEY, bypass_gate: true }
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
    end

    it "denies server_context with only caller_id (no api_key)" do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { caller_id: "admin" }
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "denies nil server_context" do
      response = tool_schema.call(model_name: "Account", server_context: nil)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "denies non-hash server_context (string) without crashing" do
      response = tool_schema.call(model_name: "Account", server_context: "admin")
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "denies non-hash server_context (array) without crashing" do
      response = tool_schema.call(model_name: "Account", server_context: ["admin"])
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # Auth implementation safety — Claim 7.7, 7.8
  # -------------------------------------------------------------------
  describe "auth implementation safety" do
    it "IdentityResolver uses secure_compare (not ==)" do
      # Verify the method source calls secure_compare
      source = Wild::Introspection::Identity::IdentityResolver.method(:resolve).source_location
      file_content = File.read(source.first)

      expect(file_content).to include("secure_compare")
      expect(file_content).not_to match(/==\s*key/) # no naive string comparison
    end

    it "rejects near-miss API key (prefix match with extra chars)" do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: "#{Wild::Introspection::TestSupport::TestConfigHelper::TEST_API_KEY}-extra" }
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "rejects API key with null byte appended" do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: "#{Wild::Introspection::TestSupport::TestConfigHelper::TEST_API_KEY}\0" }
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "rejects empty string API key" do
      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: "" }
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # Audit under error conditions — Claim 7.25, 7.9
  # -------------------------------------------------------------------
  describe "audit under error conditions" do
    let(:audit_records) { [] }

    before do
      allow(Wild::Introspection::Audit::AuditLogger).to receive(:log) do |record|
        audit_records << record
      end
    end

    it "produces audit record even when guard block raises QueryTimeoutError" do
      allow(Timeout).to receive(:timeout).and_raise(
        Wild::Introspection::QueryTimeoutError, "Timed out"
      )

      tool_lookup.call(model_name: "Account", id: "1", server_context: authenticated_server_context)

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("timeout")
    end

    it "produces audit record when guard block raises unexpected error" do
      allow(Wild::Introspection::Adapter::RecordLookup).to receive(:find_by_id).and_raise(
        StandardError, "unexpected boom"
      )

      tool_lookup.call(model_name: "Account", id: "1", server_context: authenticated_server_context)

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("error")
    end

    it "gate denial still produces audit record" do
      tool_schema.call(model_name: "Account", server_context: nil)

      expect(audit_records.size).to eq(1)
      expect(audit_records.first.outcome).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # Audit append-only integrity — Claim 7.9
  # -------------------------------------------------------------------
  describe "audit append-only integrity" do
    it "AuditRecord is frozen after creation" do
      record = Wild::Introspection::Audit::AuditRecord.new(
        tool_name: "test", guard_result: "allowed", outcome: "success", duration_ms: 1
      )
      expect(record).to be_frozen
    end

    it "AuditRecord fields cannot be modified" do
      record = Wild::Introspection::Audit::AuditRecord.new(
        tool_name: "test", guard_result: "allowed", outcome: "success", duration_ms: 1
      )

      expect { record.instance_variable_set(:@outcome, "hacked") }.to raise_error(FrozenError)
    end
  end

  # -------------------------------------------------------------------
  # Conservative defaults — Claim 9.1
  # -------------------------------------------------------------------
  describe "conservative defaults" do
    it "denies all model access with empty allowlist YAML" do
      Dir.mktmpdir do |dir|
        %w[access_policy.yml blocked_resources.yml].each do |f|
          File.write(File.join(dir, f), "version: 1\n")
        end
        Wild::Introspection.configure do |config|
          config.access_policy_path = File.join(dir, "access_policy.yml")
          config.blocked_resources_path = File.join(dir, "blocked_resources.yml")
        end
        Wild::Introspection.configuration.api_keys = [
          { key: Wild::Introspection::TestSupport::TestConfigHelper::TEST_API_KEY, name: "test-agent" }
        ]

        response = tool_schema.call(model_name: "Account", server_context: authenticated_server_context)
        expect(parse_response(response)[:status]).to eq("denied")
      end
    end

    it "denies all tools for unconfigured system (no API keys)" do
      Wild::Introspection.configuration.api_keys = []

      response = tool_schema.call(
        model_name: "Account",
        server_context: { api_key: "any-key" }
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end
end

# rubocop:enable RSpec/DescribeClass
