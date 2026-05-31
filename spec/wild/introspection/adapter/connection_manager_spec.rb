# frozen_string_literal: true

RSpec.describe Wild::Introspection::Adapter::ConnectionManager do
  describe ".connection" do
    it "returns primary connection when no replica is configured" do
      expect(described_class.connection).to eq(ActiveRecord::Base.connection)
    end
  end

  describe ".replica_configured?" do
    it "returns false by default" do
      expect(described_class.replica_configured?).to be(false)
    end

    it "returns true after configure is called with a URL" do
      described_class.configure(replica_url: "sqlite3::memory:")
      expect(described_class.replica_configured?).to be(true)
    end

    it "returns false for nil URL" do
      described_class.configure(replica_url: nil)
      expect(described_class.replica_configured?).to be(false)
    end

    it "returns false for empty URL" do
      described_class.configure(replica_url: "")
      expect(described_class.replica_configured?).to be(false)
    end
  end

  describe ".reset!" do
    it "clears replica configuration" do
      described_class.configure(replica_url: "sqlite3::memory:")
      described_class.reset!
      expect(described_class.replica_configured?).to be(false)
    end
  end
end
