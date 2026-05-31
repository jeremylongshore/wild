# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Adversarial tests for write bypass and code execution prevention.
#
# Safety claims covered: 1.4, 8.2, 8.6, 8.7, 8.8, 8.10, 1.11-edge
# These tests verify that no user-supplied input can trigger dynamic dispatch,
# SQL injection, or arbitrary code execution.
RSpec.describe "Write Bypass Adversarial", :adversarial, :safety do
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

  let(:ctx) { authenticated_server_context }
  let(:tool_schema) { Wild::Introspection::Server::Tools::InspectModelSchema }
  let(:tool_lookup) { Wild::Introspection::Server::Tools::LookupRecordById }
  let(:tool_filter) { Wild::Introspection::Server::Tools::FindRecordsByFilter }

  def parse_response(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  # -------------------------------------------------------------------
  # Dynamic dispatch prevention — Claim 8.2, 8.6
  # -------------------------------------------------------------------
  describe "dynamic dispatch prevention" do
    it 'denies model_name payload "Account.destroy_all"' do
      response = tool_schema.call(model_name: "Account.destroy_all", server_context: ctx)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it 'denies model_name payload "eval(\'exit\')"' do
      response = tool_schema.call(model_name: "eval('exit')", server_context: ctx)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "treats id containing Ruby code as opaque string" do
      response = tool_lookup.call(model_name: "Account", id: 'system("rm -rf /")', server_context: ctx)
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("not_found")
    end

    it "treats filter value containing Ruby code as opaque string" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: 'Kernel.exec("id")',
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end

    it 'denies field parameter "__send__"' do
      response = tool_filter.call(
        model_name: "Account", field: "__send__", value: "destroy_all",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it 'denies field parameter "instance_eval"' do
      response = tool_filter.call(
        model_name: "Account", field: "instance_eval", value: "malicious",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # SQL injection via tool parameters — Claim 8.7, 8.8
  # -------------------------------------------------------------------
  describe "SQL injection via tool parameters" do
    it "treats SQL DROP as literal filter value" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: "'; DROP TABLE users; --",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end

    it "treats OR tautology as literal filter value" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: "' OR '1'='1",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end

    it "treats UNION SELECT as literal filter value" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: "' UNION SELECT * FROM users --",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end

    it "treats INSERT injection in id as not_found" do
      response = tool_lookup.call(
        model_name: "Account", id: "1; INSERT INTO users VALUES(99)",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("not_found")
    end

    it "treats SQL comment injection as literal filter value" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: "value /* */ OR 1=1",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end
  end

  # -------------------------------------------------------------------
  # Code execution via model_name — Claim 8.10, 1.4
  # -------------------------------------------------------------------
  describe "code execution via model_name" do
    %w[Object Kernel File BasicObject Module Class].each do |dangerous_const|
      it "denies dangerous constant #{dangerous_const}" do
        response = tool_schema.call(model_name: dangerous_const, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    it 'denies global prefix "::Account"' do
      response = tool_schema.call(model_name: "::Account", server_context: ctx)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it 'denies null byte injection "Account\x00evil"' do
      response = tool_schema.call(model_name: "Account\x00evil", server_context: ctx)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # DB state integrity across adversarial sequences — bz3.2
  # -------------------------------------------------------------------
  describe "DB state integrity across multi-tool adversarial sequence" do
    def snapshot_db_state
      {
        account_count: Account.count,
        user_count: User.count,
        feature_flag_count: FeatureFlag.count,
        account_ids: Account.pluck(:id).sort,
        user_ids: User.pluck(:id).sort,
        account_names: Account.pluck(:name).sort
      }
    end

    before do
      User.create!(account: Account.first, email: "test@example.com", name: "Test User",
                   password_digest: "hashed", otp_secret: "secret", credit_card_number: "4111")
      FeatureFlag.create!(key: "beta_access", enabled: true, description: "Beta feature")
    end

    it "database state identical before and after all three tools with destructive payloads" do
      before_state = snapshot_db_state

      # Schema tool with destructive model names
      ["DROP TABLE users", "DELETE FROM accounts", "UPDATE users SET"].each do |payload|
        tool_schema.call(model_name: payload, server_context: ctx)
      end

      # Lookup tool with destructive IDs
      ["1; DROP TABLE users", "1; DELETE FROM accounts", "1); UPDATE users SET email="].each do |payload|
        tool_lookup.call(model_name: "Account", id: payload, server_context: ctx)
      end

      # Filter tool with destructive values
      ["'; DROP TABLE users; --", "'; DELETE FROM accounts; --",
       "'; UPDATE users SET name='pwned'; --"].each do |payload|
        tool_filter.call(model_name: "Account", field: "name", value: payload, server_context: ctx)
      end

      expect(snapshot_db_state).to eq(before_state)
    end

    it "no new records created by INSERT payloads" do
      before_state = snapshot_db_state

      ["'; INSERT INTO users (email, name) VALUES ('evil@example.com', 'Evil'); --",
       "1; INSERT INTO accounts (name, slug) VALUES ('Evil Corp', 'evil')"].each do |payload|
        tool_filter.call(model_name: "Account", field: "name", value: payload, server_context: ctx)
        tool_lookup.call(model_name: "Account", id: payload, server_context: ctx)
      end

      after_state = snapshot_db_state
      expect(after_state[:account_count]).to eq(before_state[:account_count])
      expect(after_state[:user_count]).to eq(before_state[:user_count])
      expect(after_state[:feature_flag_count]).to eq(before_state[:feature_flag_count])
    end

    it "no records deleted by DELETE payloads" do
      before_state = snapshot_db_state

      ["'; DELETE FROM accounts; --", "'; TRUNCATE TABLE users; --",
       "1; DELETE FROM feature_flags WHERE 1=1"].each do |payload|
        tool_filter.call(model_name: "Account", field: "name", value: payload, server_context: ctx)
        tool_lookup.call(model_name: "Account", id: payload, server_context: ctx)
        tool_schema.call(model_name: payload, server_context: ctx)
      end

      after_state = snapshot_db_state
      expect(after_state[:account_count]).to eq(before_state[:account_count])
      expect(after_state[:user_count]).to eq(before_state[:user_count])
      expect(after_state[:feature_flag_count]).to eq(before_state[:feature_flag_count])
    end

    it "no records modified by UPDATE payloads" do
      original_name = Account.first.name

      ["'; UPDATE accounts SET name='pwned'; --",
       "1; UPDATE accounts SET name='hacked' WHERE 1=1"].each do |payload|
        tool_filter.call(model_name: "Account", field: "name", value: payload, server_context: ctx)
        tool_lookup.call(model_name: "Account", id: payload, server_context: ctx)
      end

      expect(Account.first.reload.name).to eq(original_name)
    end
  end

  # -------------------------------------------------------------------
  # Prompt injection via model_name with SQL fragments — bz3.6
  # -------------------------------------------------------------------
  describe "prompt injection via model_name with SQL fragments" do
    [
      "User; DELETE FROM users",
      "Account' OR 1=1",
      "User\nDROP TABLE users",
      "User\tDROP",
      "User-- comment"
    ].each do |payload|
      it "denies model_name #{payload.inspect}" do
        response = tool_schema.call(model_name: payload, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end

  # -------------------------------------------------------------------
  # Prompt injection via field parameter with SQL operators — bz3.6
  # -------------------------------------------------------------------
  describe "prompt injection via field parameter with SQL operators" do
    [
      "name = 'admin'",
      "id > 5",
      "name; DROP TABLE"
    ].each do |payload|
      it "denies field parameter #{payload.inspect}" do
        response = tool_filter.call(
          model_name: "Account", field: payload, value: "test",
          server_context: ctx
        )
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end

  # -------------------------------------------------------------------
  # Control characters in all parameter types — bz3.6
  # -------------------------------------------------------------------
  describe "control characters in all parameter types" do
    it "denies null byte in model_name" do
      response = tool_schema.call(model_name: "Account\x00evil", server_context: ctx)
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "denies null byte in field parameter" do
      response = tool_filter.call(
        model_name: "Account", field: "name\x00evil", value: "test",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it "treats null byte in value as literal with empty results" do
      response = tool_filter.call(
        model_name: "Account", field: "name", value: "Acme\x00evil",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("ok")
      expect(parsed[:records]).to be_empty
    end

    it "treats null byte in id as not_found" do
      response = tool_lookup.call(model_name: "Account", id: "1\x00evil", server_context: ctx)
      parsed = parse_response(response)

      expect(parsed[:status]).to eq("not_found")
    end
  end

  # -------------------------------------------------------------------
  # ActiveRecord method names in value parameter — bz3.6
  # -------------------------------------------------------------------
  describe "ActiveRecord method names in value parameter" do
    %w[destroy_all() .delete send(:save)].each do |payload|
      it "treats value #{payload.inspect} as literal with empty results" do
        response = tool_filter.call(
          model_name: "Account", field: "name", value: payload,
          server_context: ctx
        )
        parsed = parse_response(response)

        expect(parsed[:status]).to eq("ok")
        expect(parsed[:records]).to be_empty
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
