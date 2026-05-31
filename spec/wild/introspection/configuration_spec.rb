# frozen_string_literal: true

RSpec.describe Wild::Introspection::Configuration do
  include Wild::Introspection::TestSupport::TestConfigHelper

  describe "#load!" do
    it "loads both policy files and builds model registry" do
      configure_with_test_fixtures!
      config = Wild::Introspection.configuration

      expect(config.model_registry).to include("Account", "User", "FeatureFlag")
    end

    it "excludes blocked models from the registry" do
      configure_with_test_fixtures!
      config = Wild::Introspection.configuration

      expect(config.model_registry).not_to include("CreditCard", "ApiKey")
    end

    it "freezes policy data after loading" do
      configure_with_test_fixtures!
      config = Wild::Introspection.configuration

      expect(config.model_registry).to be_frozen
      expect(config.defaults).to be_frozen
    end
  end

  describe "#resolve_model" do
    before { configure_with_test_fixtures! }

    it "returns the AR class for an allowed model" do
      expect(Wild::Introspection.configuration.resolve_model("Account")).to eq(Account)
    end

    it "returns nil for a blocked model" do
      expect(Wild::Introspection.configuration.resolve_model("CreditCard")).to be_nil
    end

    it "returns nil for a nonexistent model" do
      expect(Wild::Introspection.configuration.resolve_model("Nonexistent")).to be_nil
    end

    it "returns nil for an unlisted model" do
      expect(Wild::Introspection.configuration.resolve_model("ApiKey")).to be_nil
    end
  end

  describe "#model_config" do
    before { configure_with_test_fixtures! }

    it "returns per-model overrides" do
      config = Wild::Introspection.configuration.model_config("Account")
      expect(config[:max_rows]).to eq(100)
    end

    it "uses defaults when no per-model override exists" do
      config = Wild::Introspection.configuration.model_config("User")
      expect(config[:max_rows]).to eq(50)
      expect(config[:query_timeout_ms]).to eq(5000)
    end

    it "tracks columns mode correctly" do
      expect(Wild::Introspection.configuration.model_config("Account")[:columns_mode]).to eq(:all_except_blocked)
      expect(Wild::Introspection.configuration.model_config("User")[:columns_mode]).to eq(:explicit)
      expect(Wild::Introspection.configuration.model_config("FeatureFlag")[:columns_mode]).to eq(:all)
    end

    it "stores explicit columns as string array" do
      config = Wild::Introspection.configuration.model_config("User")
      expect(config[:explicit_columns]).to eq(%w[id email name status created_at updated_at])
    end
  end

  describe "validation errors" do
    it "raises ConfigError when access_policy_path is missing" do
      expect do
        Wild::Introspection.configure do |config|
          config.blocked_resources_path = "some/path.yml"
        end
      end.to raise_error(Wild::Introspection::ConfigError, /access_policy_path is required/)
    end

    it "raises ConfigError when blocked_resources_path is missing" do
      expect do
        Wild::Introspection.configure do |config|
          config.access_policy_path = "some/path.yml"
        end
      end.to raise_error(Wild::Introspection::ConfigError, /blocked_resources_path is required/)
    end

    it "raises ConfigError when policy file does not exist" do
      expect do
        Wild::Introspection.configure do |config|
          config.access_policy_path = "/nonexistent/access_policy.yml"
          config.blocked_resources_path = "/nonexistent/blocked_resources.yml"
        end
      end.to raise_error(Wild::Introspection::ConfigError, /not found/)
    end
  end

  describe "safe_resolve_constant" do
    before { configure_with_test_fixtures! }

    it "does not resolve constants with invalid patterns" do
      config = Wild::Introspection.configuration
      # These should all return nil via the model registry
      expect(config.resolve_model("lower_case")).to be_nil
      expect(config.resolve_model("With Spaces")).to be_nil
      expect(config.resolve_model("Has::lower")).to be_nil
    end
  end
end
