# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Guard::ColumnResolver do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".accessible_columns" do
    context "for Account (all_except_blocked mode)" do
      it "returns all columns minus model-specific and wildcard blocked columns" do
        result = described_class.accessible_columns("Account")

        expect(result).to include("id", "name", "slug", "plan", "created_at", "updated_at")
        expect(result).not_to include("stripe_customer_id", "tax_id")
        expect(result).not_to include("ssn")
      end

      it "strips wildcard blocked columns even when they exist on the model" do
        result = described_class.accessible_columns("Account")

        expect(result).not_to include("ssn", "credit_card_number")
      end
    end

    context "for User (explicit mode)" do
      it "returns only the explicitly listed columns" do
        result = described_class.accessible_columns("User")

        expect(result).to eq(%w[id email name status created_at updated_at])
      end

      it "excludes columns not in the explicit list even if they exist on the model" do
        result = described_class.accessible_columns("User")

        expect(result).not_to include("account_id", "password_digest", "otp_secret", "credit_card_number")
      end

      it "applies denylist on top of explicit list" do
        result = described_class.accessible_columns("User")

        expect(result).not_to include("password_digest", "otp_secret", "ssn", "credit_card_number")
      end
    end

    context "for FeatureFlag (all mode)" do
      it "returns all columns when no blocked columns exist on the model" do
        result = described_class.accessible_columns("FeatureFlag")

        expect(result).to eq(%w[id key enabled description created_at updated_at])
      end

      it "would strip wildcard blocked columns if they existed on the model" do
        result = described_class.accessible_columns("FeatureFlag")

        expect(result).not_to include("ssn", "credit_card_number")
      end
    end

    context "for a blocked model" do
      it "returns nil for CreditCard" do
        expect(described_class.accessible_columns("CreditCard")).to be_nil
      end

      it "returns nil for ApiKey" do
        expect(described_class.accessible_columns("ApiKey")).to be_nil
      end
    end

    context "for an unknown model" do
      it "returns nil" do
        expect(described_class.accessible_columns("NonExistentModel")).to be_nil
      end
    end

    it "returns a frozen array" do
      result = described_class.accessible_columns("Account")

      expect(result).to be_frozen
    end

    it "denylist always takes precedence over allowlist" do
      # Even in :all mode, blocked columns are stripped
      all_mode_result = described_class.accessible_columns("FeatureFlag")
      expect(all_mode_result).not_to include("ssn", "credit_card_number")

      # Even in :all_except_blocked mode, both model-specific and wildcard blocks apply
      except_blocked_result = described_class.accessible_columns("Account")
      expect(except_blocked_result).not_to include("stripe_customer_id", "tax_id", "ssn")

      # Even in :explicit mode, denylist is applied after allowlist
      explicit_result = described_class.accessible_columns("User")
      expect(explicit_result).not_to include("password_digest", "otp_secret")
    end
  end
end

# rubocop:enable RSpec/ContextWording
