# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Session::Store do
  describe "#create" do
    it "creates a session with a generated id" do
      store = described_class.new
      session = store.create

      expect(session).to be_a(Wild::CapabilityGate::Session)
      expect(session.id).to match(/\A[0-9a-f-]{36}\z/)
      expect(store.size).to eq(1)
    end

    it "creates a session with a custom id" do
      store = described_class.new
      session = store.create(id: "custom-id")

      expect(session.id).to eq("custom-id")
    end

    it "creates a session with a custom ttl" do
      store = described_class.new
      session = store.create(ttl: 60)

      expect(session).not_to be_expired
    end
  end

  describe "#find" do
    it "returns the session by id" do
      store = described_class.new
      created = store.create(id: "my-session")

      found = store.find("my-session")
      expect(found).to be(created)
    end

    it "returns nil for unknown id" do
      store = described_class.new
      expect(store.find("nonexistent")).to be_nil
    end

    it "returns nil and removes expired sessions" do
      store = described_class.new
      store.create(id: "expired-session", ttl: 0)

      expect(store.find("expired-session")).to be_nil
      expect(store.size).to eq(0)
    end
  end

  describe "#cleanup" do
    it "removes expired sessions and returns count" do
      store = described_class.new
      store.create(id: "fresh", ttl: 3600)
      store.create(id: "expired-1", ttl: 0)
      store.create(id: "expired-2", ttl: 0)

      removed = store.cleanup
      expect(removed).to eq(2)
      expect(store.size).to eq(1)
      expect(store.find("fresh")).not_to be_nil
    end

    it "returns 0 when nothing expired" do
      store = described_class.new
      store.create(ttl: 3600)

      expect(store.cleanup).to eq(0)
    end
  end

  describe "#clear" do
    it "removes all sessions" do
      store = described_class.new
      store.create
      store.create

      store.clear
      expect(store.size).to eq(0)
    end
  end

  describe "#size" do
    it "returns 0 for empty store" do
      expect(described_class.new.size).to eq(0)
    end

    it "tracks the number of sessions" do
      store = described_class.new
      store.create
      store.create
      expect(store.size).to eq(2)
    end
  end

  describe "default_ttl" do
    it "uses the default TTL for created sessions" do
      store = described_class.new(default_ttl: 0)
      session = store.create

      expect(session).to be_expired
    end
  end
end
