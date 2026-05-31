# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Identity::SessionContext do
  describe "defaults" do
    subject(:context) { described_class.new(caller_id: "user_1") }

    it "defaults caller_type to unknown" do
      expect(context.caller_type).to eq("unknown")
    end

    it "defaults authenticated to false" do
      expect(context.authenticated).to be(false)
    end

    it "defaults gate_result to not_checked" do
      expect(context.gate_result).to eq("not_checked")
    end

    it "defaults capabilities to empty array" do
      expect(context.capabilities).to eq([])
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(described_class.new(caller_id: "x")).to be_frozen
    end
  end

  describe "#anonymous?" do
    it "returns true when caller_id is nil" do
      expect(described_class.new(caller_id: nil)).to be_anonymous
    end

    it "returns true when caller_id is empty" do
      expect(described_class.new(caller_id: "")).to be_anonymous
    end

    it "returns true when caller_id is whitespace" do
      expect(described_class.new(caller_id: "  ")).to be_anonymous
    end

    it "returns false when caller_id is present" do
      expect(described_class.new(caller_id: "user_1")).not_to be_anonymous
    end
  end

  describe "#authenticated?" do
    it "returns true when authenticated is true" do
      ctx = described_class.new(caller_id: "x", authenticated: true)
      expect(ctx).to be_authenticated
    end

    it "returns false when authenticated is false" do
      ctx = described_class.new(caller_id: "x", authenticated: false)
      expect(ctx).not_to be_authenticated
    end
  end

  describe "#gate_allowed?" do
    it "returns true when gate_result is allowed" do
      ctx = described_class.new(caller_id: "x", gate_result: "allowed")
      expect(ctx).to be_gate_allowed
    end

    it "returns false when gate_result is denied" do
      ctx = described_class.new(caller_id: "x", gate_result: "denied")
      expect(ctx).not_to be_gate_allowed
    end
  end

  describe "#gate_denied?" do
    it "returns true when gate_result is denied" do
      ctx = described_class.new(caller_id: "x", gate_result: "denied")
      expect(ctx).to be_gate_denied
    end
  end

  describe "#with_gate_result" do
    it "returns a new context with updated gate_result" do
      original = described_class.new(caller_id: "user_1", authenticated: true)
      updated = original.with_gate_result("allowed", updated_capabilities: [:read])

      expect(updated.gate_result).to eq("allowed")
      expect(updated.capabilities).to eq([:read])
      expect(updated.caller_id).to eq("user_1")
      expect(updated.authenticated).to be(true)
    end

    it "does not mutate the original" do
      original = described_class.new(caller_id: "user_1")
      original.with_gate_result("allowed")

      expect(original.gate_result).to eq("not_checked")
    end
  end
end
