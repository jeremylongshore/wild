# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::CacheExecutor do
  let(:adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:executor) { described_class.new }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = Wild::AdminTools::TestSupport::TestJobAdapter.new
      c.cache_adapter = adapter
      c.flag_adapter = Wild::AdminTools::TestSupport::TestFlagAdapter.new
    end
    adapter.seed_key("users:1", "cached_user_data")
    adapter.seed_key("users:2", "another_user")
    adapter.seed_key("posts:latest", "post_data")
  end

  describe "read actions" do
    it_behaves_like "a read action", "inspect_cache_key", { cache_key: "users:1" }
    it_behaves_like "a read action", "inspect_cache_stats", {}
    it_behaves_like "a read action", "list_cache_keys", { prefix: "users:" }

    describe "inspect_cache_key preview data" do
      it "includes cache entry details" do
        result = executor.preview("inspect_cache_key", { cache_key: "users:1" })
        expect(result.data[:entry]).to include(cache_key: "users:1", exists: true)
      end

      it "handles missing key" do
        result = executor.preview("inspect_cache_key", { cache_key: "nonexistent" })
        expect(result.data[:entry]).to include(exists: false)
      end
    end

    describe "list_cache_keys" do
      it "filters by prefix" do
        result = executor.preview("list_cache_keys", { prefix: "users:" })
        expect(result.data[:keys].size).to eq(2)
        expect(result.data[:count]).to eq(2)
      end
    end

    describe "inspect_cache_stats" do
      it "returns aggregate stats" do
        result = executor.preview("inspect_cache_stats", {})
        expect(result.data[:stats]).to include(:total_keys)
      end
    end
  end

  describe "mutating actions" do
    it_behaves_like "a mutating action", "invalidate_cache_key", "mutate", { cache_key: "users:1" }
    it_behaves_like "a mutating action", "invalidate_cache_pattern", "mutate_destructive",
                    { pattern: "users:" }

    describe "invalidate_cache_key" do
      it "deletes the key" do
        result = executor.execute("invalidate_cache_key", { cache_key: "users:1" })
        expect(result.data[:deleted]).to be true

        entry = adapter.read_key("users:1")
        expect(entry[:exists]).to be false
      end
    end

    describe "invalidate_cache_pattern" do
      it_behaves_like "a safe preview", "invalidate_cache_pattern", { pattern: "users:" }

      it "returns estimated_affected in preview" do
        result = executor.preview("invalidate_cache_pattern", { pattern: "users:" })
        expect(result.data[:estimated_affected]).to eq(2)
      end

      it "deletes matching keys" do
        result = executor.execute("invalidate_cache_pattern", { pattern: "users:" })
        expect(result.data[:deleted_count]).to eq(2)
      end
    end
  end

  describe "state capture" do
    it "captures before/after snapshots on execute" do
      result = executor.execute("invalidate_cache_key", { cache_key: "users:1" })
      expect(result.before_snapshot).to include(cache_key: "users:1", exists: true)
      expect(result.after_snapshot).to include(cache_key: "users:1", cleared: true)
    end
  end
end
