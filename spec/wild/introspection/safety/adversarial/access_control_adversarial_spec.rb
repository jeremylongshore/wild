# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

# Adversarial tests for access control bypass attempts.
#
# Safety claims covered: 2.5, 2.8, 2.9, 3.8, 2.6-adv, 2.7-adv
# These tests verify that allowlist and denylist controls cannot be bypassed
# via case variations, encoding tricks, or information leakage.
RSpec.describe "Access Control Adversarial", :adversarial, :safety do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    Account.create!(
      name: "Acme Corp", slug: "acme", plan: "pro",
      stripe_customer_id: "cus_secret123", tax_id: "tax_secret456", ssn: "999-99-9999"
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
  # Allowlist bypass via model name case variations — Claim 2.5
  # -------------------------------------------------------------------
  describe "allowlist bypass via model name variations" do
    %w[account ACCOUNT aCcOuNt aCCOUNT].each do |variant|
      it "denies case variation #{variant.inspect}" do
        response = tool_schema.call(model_name: variant, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    it "produces identical denial shape for all case variations" do
      variants = %w[account ACCOUNT aCcOuNt]
      responses = variants.map do |v|
        parse_response(tool_schema.call(model_name: v, server_context: ctx))
      end

      responses.each_cons(2) do |a, b|
        expect(a.keys.sort).to eq(b.keys.sort)
        expect(a[:status]).to eq(b[:status])
        expect(a[:reason]).to eq(b[:reason])
      end
    end
  end

  # -------------------------------------------------------------------
  # Allowlist bypass via encoding and namespace tricks — Claim 2.8
  # -------------------------------------------------------------------
  describe "allowlist bypass via encoding/namespace tricks" do
    [
      "::Account",
      "Module::Account",
      " Account",
      "Account ",
      "Account\n",
      "Account\0"
    ].each do |variant|
      it "denies encoding trick #{variant.inspect}" do
        response = tool_schema.call(model_name: variant, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end

  # -------------------------------------------------------------------
  # Denylist column exfiltration attempts — Claim 2.9, 3.8
  # -------------------------------------------------------------------
  describe "denylist column exfiltration attempts" do
    it "raw JSON never contains blocked column names in lookup response" do
      account = Account.first
      response = tool_lookup.call(model_name: "Account", id: account.id.to_s, server_context: ctx)
      raw_text = response.content.first[:text]

      %w[stripe_customer_id tax_id ssn].each do |col|
        expect(raw_text).not_to include(col)
      end
    end

    it "raw JSON never contains blocked column values in lookup response" do
      account = Account.first
      response = tool_lookup.call(model_name: "Account", id: account.id.to_s, server_context: ctx)
      raw_text = response.content.first[:text]

      %w[cus_secret123 tax_secret456 999-99-9999].each do |val|
        expect(raw_text).not_to include(val)
      end
    end

    it "filtering on non-blocked field still strips blocked columns from results" do
      response = tool_filter.call(
        model_name: "Account", field: "slug", value: "acme", server_context: ctx
      )
      parsed = parse_response(response)

      parsed[:records].each do |record|
        expect(record.keys.map(&:to_s) & %w[stripe_customer_id tax_id ssn]).to be_empty
      end
    end

    it "schema inspection strips blocked columns from column list" do
      response = tool_schema.call(model_name: "Account", server_context: ctx)
      col_names = parse_response(response)[:columns].pluck(:name)

      %w[stripe_customer_id tax_id ssn].each do |col|
        expect(col_names).not_to include(col)
      end
    end
  end

  # -------------------------------------------------------------------
  # Information leakage via denial analysis — Claim 2.6-adv, 2.7-adv
  # -------------------------------------------------------------------
  describe "information leakage via denial analysis" do
    it "denial for blocked model is identical to denial for unknown model" do
      blocked = parse_response(tool_schema.call(model_name: "CreditCard", server_context: ctx))
      unknown = parse_response(tool_schema.call(model_name: "NonExistentModel", server_context: ctx))

      expect(blocked.keys.sort).to eq(unknown.keys.sort)
      expect(blocked[:status]).to eq(unknown[:status])
      expect(blocked[:reason]).to eq(unknown[:reason])
      expect(blocked[:message]).to eq(unknown[:message])
    end

    it "denial message never contains the requested model name" do
      %w[CreditCard ApiKey NonExistentModel].each do |model|
        parsed = parse_response(tool_schema.call(model_name: model, server_context: ctx))
        raw_text = tool_schema.call(model_name: model, server_context: ctx).content.first[:text]

        expect(raw_text).not_to include(model)
        expect(parsed[:message]).not_to include(model)
      end
    end

    it "filter denial for blocked field is identical to filter denial for nonexistent field" do
      blocked = parse_response(tool_filter.call(
                                 model_name: "Account", field: "stripe_customer_id", value: "x",
                                 server_context: ctx
                               ))
      nonexistent = parse_response(tool_filter.call(
                                     model_name: "Account", field: "totally_fake_field", value: "x",
                                     server_context: ctx
                                   ))

      expect(blocked[:status]).to eq(nonexistent[:status])
      expect(blocked[:reason]).to eq(nonexistent[:reason])
    end
  end

  # -------------------------------------------------------------------
  # Runtime configuration immutability — Claim 2.5
  # -------------------------------------------------------------------
  describe "runtime configuration immutability" do
    let(:config) { Wild::Introspection.configuration }

    it "model_registry is frozen" do
      expect(config.model_registry).to be_frozen
      expect { config.model_registry["Evil"] = { klass: Object } }.to raise_error(FrozenError)
    end

    it "blocked_models is frozen" do
      expect(config.blocked_models).to be_frozen
      expect { config.blocked_models << "Evil" }.to raise_error(FrozenError)
    end

    it "blocked_columns is frozen" do
      expect(config.blocked_columns).to be_frozen
      expect { config.blocked_columns << { "model" => "*", "columns" => ["evil"] } }.to raise_error(FrozenError)
    end

    it "defaults is frozen" do
      expect(config.defaults).to be_frozen
      expect { config.defaults["max_rows"] = 999_999 }.to raise_error(FrozenError)
    end
  end

  # -------------------------------------------------------------------
  # Table name instead of class name bypass attempts — bz3.3
  # -------------------------------------------------------------------
  describe "table name instead of class name bypass attempts" do
    %w[accounts users feature_flags].each do |table_name|
      it "denies table name #{table_name.inspect}" do
        response = tool_schema.call(model_name: table_name, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end

  # -------------------------------------------------------------------
  # SQL fragments in model_name — bz3.3
  # -------------------------------------------------------------------
  describe "SQL fragments in model_name" do
    [
      "User; DELETE FROM users",
      "Account' OR 1=1",
      "User\nDROP TABLE users",
      "User\tDROP",
      "User-- comment"
    ].each do |payload|
      it "denies SQL fragment #{payload.inspect}" do
        response = tool_schema.call(model_name: payload, server_context: ctx)
        parsed = parse_response(response)

        expect(response.error?).to be(true)
        expect(parsed[:status]).to eq("denied")
      end
    end
  end

  # -------------------------------------------------------------------
  # Model name enumeration resistance — bz3.3
  # -------------------------------------------------------------------
  describe "model name enumeration resistance" do
    it "all non-allowed model denials have identical response shape" do
      common_models = %w[
        Order Payment Invoice Subscription Role Permission Team
        Organization Session Token Notification Comment Post
        Category Product Cart Webhook Endpoint Integration Setting
      ]

      responses = common_models.map do |model|
        parse_response(tool_schema.call(model_name: model, server_context: ctx))
      end

      responses.each do |resp|
        expect(resp.keys.sort).to eq(responses.first.keys.sort)
        expect(resp[:status]).to eq(responses.first[:status])
        expect(resp[:reason]).to eq(responses.first[:reason])
        expect(resp[:message]).to eq(responses.first[:message])
      end
    end

    it "blocked-but-exists and non-existent models produce identical denials" do
      blocked_existing = parse_response(tool_schema.call(model_name: "CreditCard", server_context: ctx))
      non_existent = parse_response(tool_schema.call(model_name: "Zzzzzzzzzz", server_context: ctx))

      expect(blocked_existing.keys.sort).to eq(non_existent.keys.sort)
      expect(blocked_existing[:status]).to eq(non_existent[:status])
      expect(blocked_existing[:reason]).to eq(non_existent[:reason])
      expect(blocked_existing[:message]).to eq(non_existent[:message])
    end
  end

  # -------------------------------------------------------------------
  # Response timing consistency — bz3.3
  # -------------------------------------------------------------------
  describe "response timing consistency" do
    it "allowed, blocked, and unknown models respond within same order of magnitude" do
      measure = lambda { |model|
        times = Array.new(5) do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          tool_schema.call(model_name: model, server_context: ctx)
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        end
        times.sort[2] # median
      }

      allowed_time = measure.call("Account")
      blocked_time = measure.call("CreditCard")
      unknown_time = measure.call("Zzzzzzzzzz")

      max_time = [allowed_time, blocked_time, unknown_time].max
      min_time = [allowed_time, blocked_time, unknown_time].min

      # Generous 10x tolerance for SQLite test environment
      expect(max_time).to be < (min_time * 10)
    end
  end

  # -------------------------------------------------------------------
  # Table-prefixed column in field parameter — bz3.4
  # -------------------------------------------------------------------
  describe "table-prefixed column in field parameter" do
    it 'denies "accounts.stripe_customer_id"' do
      response = tool_filter.call(
        model_name: "Account", field: "accounts.stripe_customer_id", value: "test",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it 'denies "users.password_digest"' do
      response = tool_filter.call(
        model_name: "User", field: "users.password_digest", value: "test",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # Column-like field names that might confuse filtering — bz3.4
  # -------------------------------------------------------------------
  describe "column-like field names that might confuse filtering" do
    it 'denies "stripe_customer_id AS name"' do
      response = tool_filter.call(
        model_name: "Account", field: "stripe_customer_id AS name", value: "test",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end

    it 'denies "name, stripe_customer_id"' do
      response = tool_filter.call(
        model_name: "Account", field: "name, stripe_customer_id", value: "test",
        server_context: ctx
      )
      parsed = parse_response(response)

      expect(response.error?).to be(true)
      expect(parsed[:status]).to eq("denied")
    end
  end

  # -------------------------------------------------------------------
  # Schema and data consistency for blocked columns — bz3.4
  # -------------------------------------------------------------------
  describe "schema and data consistency for blocked columns" do
    it "schema omits blocked columns AND data omits them for Account" do
      schema_resp = parse_response(tool_schema.call(model_name: "Account", server_context: ctx))
      schema_cols = schema_resp[:columns].pluck(:name)

      account = Account.first
      data_resp = parse_response(tool_lookup.call(model_name: "Account", id: account.id.to_s, server_context: ctx))
      data_cols = data_resp[:record].keys.map(&:to_s)

      %w[stripe_customer_id tax_id ssn].each do |blocked|
        expect(schema_cols).not_to include(blocked)
        expect(data_cols).not_to include(blocked)
      end
    end

    it "wildcard-blocked columns stripped from ALL models" do
      %w[Account User].each do |model_name|
        schema_resp = parse_response(tool_schema.call(model_name: model_name, server_context: ctx))
        schema_cols = schema_resp[:columns].map { |c| c[:name] }

        %w[ssn credit_card_number].each do |blocked|
          expect(schema_cols).not_to include(blocked),
                                     "expected #{model_name} schema to not include #{blocked}"
        end
      end
    end
  end

  # -------------------------------------------------------------------
  # Column enumeration resistance — bz3.4
  # -------------------------------------------------------------------
  describe "column enumeration resistance" do
    it "filter on blocked field vs non-existent field produces identical denial shape" do
      blocked_args = { model_name: "Account", field: "stripe_customer_id",
                       value: "x", server_context: ctx }
      fake_args = { model_name: "Account", field: "totally_nonexistent_column",
                    value: "x", server_context: ctx }
      blocked = parse_response(tool_filter.call(**blocked_args))
      nonexistent = parse_response(tool_filter.call(**fake_args))

      expect(blocked.keys.sort).to eq(nonexistent.keys.sort)
      expect(blocked[:status]).to eq(nonexistent[:status])
      expect(blocked[:reason]).to eq(nonexistent[:reason])
      expect(blocked[:message]).to eq(nonexistent[:message])
    end

    it "blocked column name never appears in any response across all three tools" do
      account = Account.first
      blocked_cols = %w[stripe_customer_id tax_id]

      responses_raw = [
        tool_schema.call(model_name: "Account", server_context: ctx).content.first[:text],
        tool_lookup.call(model_name: "Account", id: account.id.to_s, server_context: ctx).content.first[:text],
        tool_filter.call(model_name: "Account", field: "name", value: "Acme Corp",
                         server_context: ctx).content.first[:text]
      ]

      responses_raw.each_with_index do |raw_json, idx|
        blocked_cols.each do |col|
          expect(raw_json).not_to include(col),
                                  "expected response ##{idx} to not contain #{col}"
        end
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
