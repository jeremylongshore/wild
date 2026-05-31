# frozen_string_literal: true

RSpec.describe Wild::Introspection::Identity::RequestContext do
  describe ".anonymous" do
    subject(:context) { described_class.anonymous }

    it "sets caller_id to anonymous" do
      expect(context.caller_id).to eq("anonymous")
    end

    it "sets caller_type to unknown" do
      expect(context.caller_type).to eq("unknown")
    end

    it "sets auth_result to rejected" do
      expect(context.auth_result).to eq(:rejected)
    end

    it "is not authenticated" do
      expect(context).not_to be_authenticated
    end
  end

  describe "authenticated context" do
    subject(:context) do
      described_class.new(
        caller_id: "agent-1", caller_type: "api_key", auth_result: :success
      )
    end

    it "is authenticated" do
      expect(context).to be_authenticated
    end

    it "exposes caller_id" do
      expect(context.caller_id).to eq("agent-1")
    end

    it "exposes caller_type" do
      expect(context.caller_type).to eq("api_key")
    end
  end

  describe "invalid context" do
    subject(:context) do
      described_class.new(
        caller_id: "unknown", caller_type: "api_key", auth_result: :invalid
      )
    end

    it "is not authenticated" do
      expect(context).not_to be_authenticated
    end
  end

  describe "immutability" do
    it "is frozen after construction" do
      context = described_class.anonymous
      expect(context).to be_frozen
    end
  end
end
