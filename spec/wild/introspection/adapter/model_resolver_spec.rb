# frozen_string_literal: true

RSpec.describe Wild::Introspection::Adapter::ModelResolver do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".resolve" do
    it "returns metadata for an allowed model" do
      result = described_class.resolve("Account")

      expect(result).to include(
        name: "Account",
        table_name: "accounts",
        primary_key: "id",
        abstract: false,
        max_rows: 100,
        query_timeout_ms: 5000
      )
    end

    it "returns nil for a blocked model" do
      expect(described_class.resolve("CreditCard")).to be_nil
    end

    it "returns nil for a nonexistent model" do
      expect(described_class.resolve("TotallyFakeModel")).to be_nil
    end

    it "returns nil for an unlisted model" do
      expect(described_class.resolve("ApiKey")).to be_nil
    end
  end

  describe ".allowed?" do
    it "returns true for allowed models" do
      expect(described_class.allowed?("Account")).to be(true)
      expect(described_class.allowed?("User")).to be(true)
      expect(described_class.allowed?("FeatureFlag")).to be(true)
    end

    it "returns false for blocked models" do
      expect(described_class.allowed?("CreditCard")).to be(false)
      expect(described_class.allowed?("ApiKey")).to be(false)
    end

    it "returns false for nonexistent models" do
      expect(described_class.allowed?("DoesNotExist")).to be(false)
    end
  end
end
