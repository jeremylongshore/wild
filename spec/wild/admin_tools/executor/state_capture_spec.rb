# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::StateCapture do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:cache_adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:flag_adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
  end

  describe "job snapshots" do
    let(:executor) { Wild::AdminTools::Executor::JobExecutor.new }

    before do
      job_adapter.seed_job("job-1", status: "dead", queue: "default", error_class: "RuntimeError",
                                    retry_count: 3)
    end

    it "captures before snapshot with failure details" do
      result = executor.execute("retry_job", { job_id: "job-1" })
      expect(result.before_snapshot).to include(
        job_id: "job-1",
        status: "dead",
        queue: "default",
        error_class: "RuntimeError",
        retry_count: 3
      )
    end

    it "captures after snapshot with new status" do
      result = executor.execute("retry_job", { job_id: "job-1" })
      expect(result.after_snapshot).to include(
        job_id: "job-1",
        status: "enqueued"
      )
      expect(result.after_snapshot).to have_key(:enqueued_at)
    end
  end

  describe "cache snapshots" do
    let(:executor) { Wild::AdminTools::Executor::CacheExecutor.new }

    before do
      cache_adapter.seed_key("users:1", "cached_value", byte_size: 42)
    end

    it "captures before snapshot with value hash" do
      result = executor.execute("invalidate_cache_key", { cache_key: "users:1" })
      expect(result.before_snapshot).to include(
        cache_key: "users:1",
        exists: true,
        byte_size: 42
      )
      expect(result.before_snapshot[:value_hash]).to match(/\A[a-f0-9]{64}\z/)
    end

    it "captures after snapshot showing cleared" do
      result = executor.execute("invalidate_cache_key", { cache_key: "users:1" })
      expect(result.after_snapshot).to include(
        cache_key: "users:1",
        cleared: true
      )
    end
  end

  describe "flag snapshots" do
    let(:executor) { Wild::AdminTools::Executor::FlagExecutor.new }

    before do
      flag_adapter.seed_flag("beta", enabled: true, percentage: 25, actors: ["User;42"])
    end

    it "captures before snapshot with full state" do
      result = executor.execute("toggle_flag", { flag_name: "beta", enabled: false })
      expect(result.before_snapshot).to include(
        flag_name: "beta",
        enabled: true,
        percentage: 25,
        actors: ["User;42"]
      )
    end

    it "captures after snapshot with changed_at" do
      result = executor.execute("toggle_flag", { flag_name: "beta", enabled: false })
      expect(result.after_snapshot).to include(flag_name: "beta", enabled: false)
      expect(result.after_snapshot).to have_key(:changed_at)
    end
  end

  describe "read operations" do
    let(:executor) { Wild::AdminTools::Executor::JobExecutor.new }

    before { job_adapter.seed_job("job-1") }

    it "returns nil snapshots for read-only execute" do
      result = executor.execute("inspect_job", { job_id: "job-1" })
      expect(result.before_snapshot).to be_nil
      expect(result.after_snapshot).to be_nil
    end
  end
end
