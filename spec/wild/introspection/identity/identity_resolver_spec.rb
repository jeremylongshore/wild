# frozen_string_literal: true

RSpec.describe Wild::Introspection::Identity::IdentityResolver do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before do
    configure_with_test_fixtures!
    Wild::Introspection.configuration.api_keys = [
      { key: "sk-test-valid-key", name: "test-agent" },
      { key: "sk-test-second-key", name: "second-agent" }
    ]
  end

  describe ".resolve" do
    context "with a valid API key" do
      it "returns an authenticated context" do
        context = described_class.resolve(api_key: "sk-test-valid-key")

        expect(context).to be_authenticated
        expect(context.caller_id).to eq("test-agent")
        expect(context.caller_type).to eq("api_key")
        expect(context.auth_result).to eq(:success)
      end

      it "resolves the correct caller for each key" do
        context = described_class.resolve(api_key: "sk-test-second-key")

        expect(context.caller_id).to eq("second-agent")
      end
    end

    context "with an invalid API key" do
      it "returns an unauthenticated context with auth_result invalid" do
        context = described_class.resolve(api_key: "sk-wrong-key")

        expect(context).not_to be_authenticated
        expect(context.auth_result).to eq(:invalid)
        expect(context.caller_id).to eq("unknown")
      end
    end

    context "with a nil API key" do
      it "returns an anonymous context" do
        context = described_class.resolve(api_key: nil)

        expect(context).not_to be_authenticated
        expect(context.auth_result).to eq(:rejected)
        expect(context.caller_id).to eq("anonymous")
      end
    end

    context "with an empty string API key" do
      it "returns an anonymous context" do
        context = described_class.resolve(api_key: "")

        expect(context).not_to be_authenticated
        expect(context.auth_result).to eq(:rejected)
      end
    end

    context "with no configured API keys" do
      before do
        Wild::Introspection.configuration.api_keys = []
      end

      it "rejects all keys" do
        context = described_class.resolve(api_key: "sk-test-valid-key")

        expect(context).not_to be_authenticated
        expect(context.auth_result).to eq(:invalid)
      end
    end

    context "with mismatched key lengths" do
      it "handles short keys without raising" do
        expect do
          described_class.resolve(api_key: "short")
        end.not_to raise_error
      end

      it "handles long keys without raising" do
        expect do
          described_class.resolve(api_key: "a" * 1000)
        end.not_to raise_error
      end
    end
  end
end
