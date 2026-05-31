# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Guard::QueryGuard do
  include Wild::Introspection::TestSupport::TestConfigHelper

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

  let(:flag) { FeatureFlag.create!(key: "dark_mode", enabled: true, description: "Toggle dark mode") }

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    # Force creation of lazy-evaluated records
    account
    user
    flag
  end

  describe ".inspect_schema" do
    context "for an allowed model" do
      it "returns only accessible columns in the schema" do
        result = described_class.inspect_schema("Account", request_context: ctx)

        expect(result[:status]).to eq(:ok)
        col_names = result[:columns].pluck(:name)
        expect(col_names).to include("id", "name", "slug", "plan")
        expect(col_names).not_to include("stripe_customer_id", "tax_id", "ssn")
      end

      it "preserves column metadata for accessible columns" do
        result = described_class.inspect_schema("Account", request_context: ctx)

        id_col = result[:columns].find { |c| c[:name] == "id" }
        expect(id_col).to include(type: :integer)
      end

      it "preserves associations in the schema" do
        result = described_class.inspect_schema("Account", request_context: ctx)

        expect(result[:associations]).to be_an(Array)
      end
    end

    context "for a blocked model" do
      it "returns denial" do
        result = described_class.inspect_schema("CreditCard", request_context: ctx)

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    context "for an unknown model" do
      it "returns the same denial as a blocked model" do
        blocked = described_class.inspect_schema("CreditCard", request_context: ctx)
        unknown = described_class.inspect_schema("FakeModel", request_context: ctx)

        expect(blocked).to eq(unknown)
      end
    end
  end

  describe ".find_by_id" do
    context "for an allowed model" do
      it "returns record with only accessible columns" do
        result = described_class.find_by_id("Account", account.id, request_context: ctx)

        expect(result[:status]).to eq(:ok)
        expect(result[:record]).to include("id", "name", "slug", "plan")
      end

      it "silently strips blocked columns from the record" do
        result = described_class.find_by_id("Account", account.id, request_context: ctx)

        expect(result[:record].keys).not_to include("stripe_customer_id", "tax_id", "ssn")
      end

      it "does not include any marker that columns were removed" do
        result = described_class.find_by_id("Account", account.id, request_context: ctx)

        expect(result.keys).to eq(%i[status record])
      end

      it "strips blocked column values completely" do
        result = described_class.find_by_id("Account", account.id, request_context: ctx)

        expect(result[:record].values).not_to include("cus_secret123", "tax_secret456", "999-99-9999")
      end
    end

    context "for User with explicit columns" do
      it "returns only the explicitly allowed columns" do
        result = described_class.find_by_id("User", user.id, request_context: ctx)

        expect(result[:status]).to eq(:ok)
        expect(result[:record].keys.sort).to eq(%w[created_at email id name status updated_at])
      end

      it "does not include sensitive columns" do
        result = described_class.find_by_id("User", user.id, request_context: ctx)

        expect(result[:record].keys).not_to include(
          "password_digest", "otp_secret", "credit_card_number", "account_id"
        )
      end
    end

    context "for a nonexistent record" do
      it "returns not_found" do
        result = described_class.find_by_id("Account", 99_999, request_context: ctx)

        expect(result[:status]).to eq(:not_found)
      end
    end

    context "for a blocked model" do
      it "returns denial" do
        result = described_class.find_by_id("CreditCard", 1, request_context: ctx)

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    it "does not reveal model names in denial messages" do
      result = described_class.find_by_id("CreditCard", 1, request_context: ctx)

      expect(result[:message]).not_to include("CreditCard")
    end
  end

  describe ".find_by_filter" do
    context "with an accessible filter field" do
      it "returns filtered records with only accessible columns" do
        result = described_class.find_by_filter("Account", field: "slug", value: "acme", request_context: ctx)

        expect(result[:status]).to eq(:ok)
        expect(result[:records].size).to eq(1)
        expect(result[:records].first).to include("name" => "Acme Corp", "slug" => "acme")
      end

      it "strips blocked columns from filtered results" do
        result = described_class.find_by_filter("Account", field: "slug", value: "acme", request_context: ctx)

        result[:records].each do |record|
          expect(record.keys).not_to include("stripe_customer_id", "tax_id", "ssn")
        end
      end
    end

    context "when filter field is a blocked column" do
      it "returns denial to prevent information leakage" do
        result = described_class.find_by_filter(
          "Account", field: "stripe_customer_id", value: "cus_secret123", request_context: ctx
        )

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end

      it "denies wildcard-blocked columns as filter fields" do
        result = described_class.find_by_filter(
          "Account", field: "ssn", value: "999-99-9999", request_context: ctx
        )

        expect(result[:status]).to eq(:denied)
      end
    end

    context "when filter field does not exist" do
      it "returns denial identical to blocked column denial" do
        blocked_field = described_class.find_by_filter(
          "Account", field: "stripe_customer_id", value: "x", request_context: ctx
        )
        nonexistent_field = described_class.find_by_filter(
          "Account", field: "nonexistent_column", value: "x", request_context: ctx
        )

        expect(blocked_field).to eq(nonexistent_field)
      end
    end

    context "for User with explicit columns" do
      it "allows filtering on an explicitly listed column" do
        result = described_class.find_by_filter("User", field: "status", value: "active", request_context: ctx)

        expect(result[:status]).to eq(:ok)
        expect(result[:records].first.keys.sort).to eq(%w[created_at email id name status updated_at])
      end

      it "denies filtering on a column not in the explicit list" do
        result = described_class.find_by_filter(
          "User", field: "account_id", value: account.id, request_context: ctx
        )

        expect(result[:status]).to eq(:denied)
      end
    end

    context "for a blocked model" do
      it "returns denial" do
        result = described_class.find_by_filter(
          "CreditCard", field: "number", value: "1234", request_context: ctx
        )

        expect(result[:status]).to eq(:denied)
      end
    end

    it "denial responses are uniform across all failure modes" do
      blocked_model = described_class.find_by_filter(
        "CreditCard", field: "number", value: "x", request_context: ctx
      )
      unknown_model = described_class.find_by_filter(
        "FakeModel", field: "id", value: "1", request_context: ctx
      )
      blocked_field = described_class.find_by_filter(
        "Account", field: "stripe_customer_id", value: "x", request_context: ctx
      )
      nonexistent_field = described_class.find_by_filter(
        "Account", field: "no_such_col", value: "x", request_context: ctx
      )

      expect(blocked_model).to eq(unknown_model)
      expect(blocked_model).to eq(blocked_field)
      expect(blocked_model).to eq(nonexistent_field)
    end
  end

  describe "authentication enforcement" do
    let(:anon_ctx) { anonymous_context }

    it "rejects anonymous inspect_schema" do
      result = described_class.inspect_schema("Account", request_context: anon_ctx)

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:auth_required)
    end

    it "rejects anonymous find_by_id" do
      result = described_class.find_by_id("Account", account.id, request_context: anon_ctx)

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:auth_required)
    end

    it "rejects anonymous find_by_filter" do
      result = described_class.find_by_filter(
        "Account", field: "slug", value: "acme", request_context: anon_ctx
      )

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:auth_required)
    end

    it "auth denial does not reveal model existence" do
      allowed = described_class.inspect_schema("Account", request_context: anon_ctx)
      blocked = described_class.inspect_schema("CreditCard", request_context: anon_ctx)
      unknown = described_class.inspect_schema("FakeModel", request_context: anon_ctx)

      expect(allowed[:reason]).to eq(:auth_required)
      expect(blocked[:reason]).to eq(:auth_required)
      expect(unknown[:reason]).to eq(:auth_required)
    end
  end

  describe "hard ceiling enforcement" do
    it "clamps max_rows at the hard ceiling in configuration" do
      config = Wild::Introspection.configuration.model_config("Account")

      expect(config[:max_rows]).to be <= Wild::Introspection::Configuration::HARD_ROW_CEILING
    end

    it "clamps query_timeout_ms at the hard ceiling in configuration" do
      config = Wild::Introspection.configuration.model_config("Account")

      expect(config[:query_timeout_ms]).to be <= Wild::Introspection::Configuration::HARD_TIMEOUT_CEILING_MS
    end

    it "clamps defaults at hard ceilings" do
      defaults = Wild::Introspection.configuration.defaults

      expect(defaults["max_rows"]).to be <= Wild::Introspection::Configuration::HARD_ROW_CEILING
      expect(defaults["query_timeout_ms"]).to be <= Wild::Introspection::Configuration::HARD_TIMEOUT_CEILING_MS
    end

    it "defines correct hard ceiling constants" do
      expect(Wild::Introspection::Configuration::HARD_ROW_CEILING).to eq(1000)
      expect(Wild::Introspection::Configuration::HARD_TIMEOUT_CEILING_MS).to eq(30_000)
      expect(Wild::Introspection::Configuration::MINIMUM_TIMEOUT_MS).to eq(100)
    end
  end

  describe "safety invariants" do
    it "blocked columns never appear in find_by_id responses" do
      result = described_class.find_by_id("Account", account.id, request_context: ctx)

      blocked = Wild::Introspection.configuration.blocked_columns_for("Account")
      expect(result[:record].keys & blocked).to be_empty
    end

    it "blocked columns never appear in find_by_filter responses" do
      result = described_class.find_by_filter("Account", field: "slug", value: "acme", request_context: ctx)

      blocked = Wild::Introspection.configuration.blocked_columns_for("Account")
      result[:records].each do |record|
        expect(record.keys & blocked).to be_empty
      end
    end

    it "blocked columns never appear in inspect_schema responses" do
      result = described_class.inspect_schema("Account", request_context: ctx)

      blocked = Wild::Introspection.configuration.blocked_columns_for("Account")
      col_names = result[:columns].pluck(:name)
      expect(col_names & blocked).to be_empty
    end
  end
end

# rubocop:enable RSpec/ContextWording
