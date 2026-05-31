# frozen_string_literal: true

RSpec.describe Wild::Introspection::Adapter::ModelReflector do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".reflect" do
    it "returns ok status with metadata for an allowed model" do
      result = described_class.reflect("Account")

      expect(result[:status]).to eq(:ok)
      expect(result[:model]).to include(name: "Account", table_name: "accounts")
    end

    it "returns denial for a blocked model" do
      result = described_class.reflect("CreditCard")

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:model_not_allowed)
    end

    it "returns denial for a nonexistent model" do
      result = described_class.reflect("TotallyFakeModel")

      expect(result[:status]).to eq(:denied)
      expect(result[:reason]).to eq(:model_not_allowed)
    end

    it "returns identical denial responses for blocked and nonexistent models" do
      blocked = described_class.reflect("CreditCard")
      nonexistent = described_class.reflect("TotallyFakeModel")
      unlisted = described_class.reflect("ApiKey")

      expect(blocked).to eq(nonexistent)
      expect(blocked).to eq(unlisted)
    end

    it "does not include the model name in denial messages" do
      result = described_class.reflect("CreditCard")

      expect(result[:message]).not_to include("CreditCard")
    end
  end
end
