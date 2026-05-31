# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Models::Turn do
  subject(:turn) { described_class.new(role: :user, content: "Hello world") }

  describe "#initialize" do
    it "stores role as symbol" do
      expect(turn.role).to eq(:user)
    end

    it "stores content as frozen string" do
      expect(turn.content).to eq("Hello world")
      expect(turn.content).to be_frozen
    end

    it "accepts all valid roles" do
      described_class::VALID_ROLES.each do |role|
        t = described_class.new(role: role, content: "test")
        expect(t.role).to eq(role)
      end
    end

    it "coerces string roles to symbols" do
      t = described_class.new(role: "assistant", content: "hi")
      expect(t.role).to eq(:assistant)
    end

    it "accepts nil timestamp" do
      t = described_class.new(role: :user, content: "hi")
      expect(t.timestamp).to be_nil
    end

    it "stores timestamp when provided" do
      ts = Time.utc(2026, 1, 1)
      t = described_class.new(role: :user, content: "hi", timestamp: ts)
      expect(t.timestamp).to eq(ts)
    end

    it "stores metadata as frozen hash" do
      t = described_class.new(role: :user, content: "hi", metadata: { key: "value" })
      expect(t.metadata).to eq({ key: "value" })
      expect(t.metadata).to be_frozen
    end

    it "raises ArgumentError for invalid role" do
      expect { described_class.new(role: :invalid, content: "hi") }
        .to raise_error(ArgumentError, /role must be one of/)
    end

    it "raises ArgumentError for non-String content" do
      expect { described_class.new(role: :user, content: 42) }
        .to raise_error(ArgumentError, /content must be a String/)
    end

    it "raises ArgumentError for non-Hash metadata" do
      expect { described_class.new(role: :user, content: "hi", metadata: "bad") }
        .to raise_error(ArgumentError, /metadata must be a Hash/)
    end
  end

  describe "#to_h" do
    it "returns a hash with role, content, timestamp, metadata" do
      ts = Time.utc(2026, 1, 1)
      t = described_class.new(role: :user, content: "hello", timestamp: ts)
      h = t.to_h
      expect(h[:role]).to eq(:user)
      expect(h[:content]).to eq("hello")
      expect(h[:timestamp]).to eq(ts.iso8601)
      expect(h[:metadata]).to eq({})
    end

    it "serializes nil timestamp as nil" do
      t = described_class.new(role: :user, content: "hi")
      expect(t.to_h[:timestamp]).to be_nil
    end
  end

  describe "role predicates" do
    it "#user_turn? returns true for :user" do
      expect(described_class.new(role: :user, content: "x").user_turn?).to be(true)
    end

    it "#assistant_turn? returns true for :assistant" do
      expect(described_class.new(role: :assistant, content: "x").assistant_turn?).to be(true)
    end

    it "#system_turn? returns true for :system" do
      expect(described_class.new(role: :system, content: "x").system_turn?).to be(true)
    end

    it "#tool_turn? returns true for :tool" do
      expect(described_class.new(role: :tool, content: "x").tool_turn?).to be(true)
    end

    it "#user_turn? returns false for :assistant" do
      expect(described_class.new(role: :assistant, content: "x").user_turn?).to be(false)
    end
  end
end
