# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::History::Store do
  subject(:store) { described_class.new }

  let(:record) { flake_record_with }
  let(:identity) { record.test_identity }

  describe "#record" do
    it "stores a flake record" do
      store.record(record)
      expect(store.size).to eq(1)
    end

    it "returns the stored record" do
      result = store.record(record)
      expect(result).to be_a(Wild::Analyzers::TestFlakes::Models::FlakeRecord)
    end

    it "merges when recording the same identity twice" do
      store.record(record)
      store.record(record)
      expect(store.size).to eq(1)
    end

    it "tracks different identities separately" do
      id2 = make_identity(test_name: "different test")
      record2 = flake_record_with(identity: id2)
      store.record(record)
      store.record(record2)
      expect(store.size).to eq(2)
    end
  end

  describe "#fetch" do
    it "returns nil when identity not found" do
      expect(store.fetch(identity)).to be_nil
    end

    it "returns the stored record for a known identity" do
      store.record(record)
      fetched = store.fetch(identity)
      expect(fetched.test_identity).to eq(identity)
    end
  end

  describe "#all" do
    it "returns all stored records" do
      store.record(record)
      expect(store.all.size).to eq(1)
    end

    it "returns an array copy" do
      store.record(record)
      all1 = store.all
      all2 = store.all
      expect(all1).not_to equal(all2)
    end
  end

  describe "#trend_for" do
    it "returns :stable for unknown identity" do
      expect(store.trend_for(identity)).to eq(:stable)
    end

    it "returns :stable with single snapshot" do
      store.record(record)
      expect(store.trend_for(identity)).to eq(:stable)
    end
  end

  describe "#size" do
    it "returns 0 initially" do
      expect(store.size).to eq(0)
    end
  end

  describe "#clear!" do
    it "empties the store" do
      store.record(record)
      store.clear!
      expect(store.size).to eq(0)
    end
  end

  describe "max_entries limit" do
    let(:store) { described_class.new(max_entries: 2) }

    it "enforces the max_entries limit" do
      3.times do |i|
        id = make_identity(test_name: "test_#{i}")
        r = flake_record_with(identity: id)
        store.record(r)
      end
      expect(store.size).to be <= 2
    end
  end
end
