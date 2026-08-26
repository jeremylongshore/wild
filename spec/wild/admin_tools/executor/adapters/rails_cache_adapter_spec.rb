# frozen_string_literal: true

# A Hash-backed double standing in for Rails.cache: implements only the
# methods RailsCacheAdapter actually calls (read/write/delete/exist?/keys/stats),
# nothing more, so this spec exercises the adapter's real, unmocked logic
# against a store that behaves like a real cache store would.
class FakeRailsCacheStore
  delegate :delete, :keys, to: :@data

  def initialize
    @data = {}
  end

  def write(key, value)
    @data[key] = value
  end

  def read(key)
    @data[key]
  end

  def exist?(key)
    @data.key?(key)
  end

  def stats
    { store_class: self.class.name, key_count: @data.size }
  end
end

RSpec.describe Wild::AdminTools::Executor::Adapters::RailsCacheAdapter do
  subject(:adapter) { described_class.new }

  let(:fake_store) { FakeRailsCacheStore.new }

  before { allow(Rails).to receive(:cache).and_return(fake_store) }

  it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::CacheAdapter

  describe "#read_key" do
    it "reports exists: false with byte_size 0 for a missing key" do
      result = adapter.read_key("missing")
      expect(result).to eq(cache_key: "missing", exists: false, value: nil, byte_size: 0)
    end

    it "returns the value and its marshaled byte size for a present key" do
      fake_store.write("user:1", { name: "Ada" })
      result = adapter.read_key("user:1")
      expect(result[:exists]).to be(true)
      expect(result[:value]).to eq(name: "Ada")
      expect(result[:byte_size]).to eq(Marshal.dump({ name: "Ada" }).bytesize)
    end
  end

  describe "#list_keys" do
    before do
      fake_store.write("user:1", "a")
      fake_store.write("user:2", "b")
      fake_store.write("other:1", "c")
    end

    it "does not require prefix (finding f-l10-14: CacheExecutor calls it with an empty options hash)" do
      expect { adapter.list_keys }.not_to raise_error
    end

    it "filters keys by the given prefix" do
      result = adapter.list_keys(prefix: "user:")
      expect(result).to contain_exactly({ cache_key: "user:1" }, { cache_key: "user:2" })
    end

    it "raises AdapterError when the store does not support key listing" do
      allow(fake_store).to receive(:respond_to?).with(:keys).and_return(false)
      expect { adapter.list_keys(prefix: "user:") }.to raise_error(Wild::AdminTools::AdapterError, /key listing/)
    end
  end

  describe "#cache_stats" do
    it "delegates to the store's #stats" do
      fake_store.write("k", "v")
      expect(adapter.cache_stats).to eq(store_class: "FakeRailsCacheStore", key_count: 1)
    end
  end

  describe "#count_matching_keys" do
    it "counts keys starting with the pattern" do
      fake_store.write("user:1", "a")
      fake_store.write("user:2", "b")
      fake_store.write("other:1", "c")
      expect(adapter.count_matching_keys("user:")).to eq(2)
    end
  end

  describe "#delete_key!" do
    it "reports whether the key existed and removes it" do
      fake_store.write("user:1", "a")
      result = adapter.delete_key!("user:1")
      expect(result).to eq(cache_key: "user:1", deleted: true)
      expect(fake_store.exist?("user:1")).to be(false)
    end

    it "reports deleted: false for a key that was never there" do
      expect(adapter.delete_key!("ghost")).to eq(cache_key: "ghost", deleted: false)
    end
  end

  describe "#delete_matching!" do
    it "removes every key starting with the pattern and reports the count" do
      fake_store.write("user:1", "a")
      fake_store.write("user:2", "b")
      fake_store.write("other:1", "c")
      result = adapter.delete_matching!("user:")
      expect(result).to eq(pattern: "user:", deleted_count: 2)
      expect(fake_store.keys).to contain_exactly("other:1")
    end
  end

  context "when Rails.cache is unavailable" do
    before { allow(Rails).to receive(:cache).and_return(nil) }

    it "raises AdapterError instead of a bare NoMethodError" do
      expect { adapter.read_key("k") }.to raise_error(Wild::AdminTools::AdapterError, /Rails\.cache is not available/)
    end
  end
end
