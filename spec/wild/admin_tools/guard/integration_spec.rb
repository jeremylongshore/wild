# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Guard::Pipeline end-to-end lifecycle" do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:cache_adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:flag_adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }

  let(:pipeline) do
    Wild::AdminTools::Guard::Pipeline.new(policy_config: valid_policy_config).tap do |p|
      p.register_executor(Wild::AdminTools::Executor::JobExecutor.new)
      p.register_executor(Wild::AdminTools::Executor::CacheExecutor.new)
      p.register_executor(Wild::AdminTools::Executor::FlagExecutor.new)
    end
  end

  let(:caller_id) { "operator-e2e" }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
    job_adapter.seed_job("job-e2e")
    cache_adapter.seed_key("cache:e2e", "cached_value")
    flag_adapter.seed_flag("release_flag")
  end

  after { pipeline.two_phase.nonce_manager.store.stop_sweep! }

  it "read action executes directly without a nonce" do
    result = pipeline.call("inspect_job", { job_id: "job-e2e" }, caller_id)
    expect(result.status).to eq(:success)
    expect(job_adapter.write_methods_called).to be_empty
  end

  it "mutate action follows the full preview-then-confirm lifecycle" do
    preview = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id)
    expect(preview.status).to eq(:preview)

    nonce = preview.metadata[:nonce]
    confirm = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id, nonce: nonce)
    expect(confirm.status).to eq(:success)
  end

  context "when nonce is expired" do
    it "returns denied with reason nonce_invalid" do
      preview = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id)
      nonce = preview.metadata[:nonce]

      entry = pipeline.two_phase.nonce_manager.store.fetch(nonce)
      expired_entry = Wild::AdminTools::Guard::NonceEntry.new(
        nonce: entry.nonce, binding_hash: entry.binding_hash,
        action_name: entry.action_name, caller_id: entry.caller_id,
        expires_at: Time.now.utc - 1
      )
      pipeline.two_phase.nonce_manager.store.instance_variable_get(:@mutex).synchronize do
        pipeline.two_phase.nonce_manager.store.instance_variable_get(:@entries)[nonce] = expired_entry
      end

      result = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id, nonce: nonce)
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("nonce_invalid")
    end
  end

  context "when nonce has already been consumed" do
    it "returns denied with reason nonce_invalid on second use" do
      preview = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id)
      nonce = preview.metadata[:nonce]

      pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id, nonce: nonce)
      result = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id, nonce: nonce)
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("nonce_invalid")
    end
  end

  context "when params in confirmation differ from preview" do
    it "returns denied with reason nonce_invalid" do
      job_adapter.seed_job("job-other")
      preview = pipeline.call("retry_job", { job_id: "job-e2e" }, caller_id)
      nonce = preview.metadata[:nonce]

      result = pipeline.call("retry_job", { job_id: "job-other" }, caller_id, nonce: nonce)
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("nonce_invalid")
    end
  end

  context "when blast radius is exceeded" do
    it "returns denied with reason blast_radius_exceeded" do
      150.times { |i| job_adapter.seed_job("bulk-job-#{i}", queue: "overloaded") }

      result = pipeline.call(
        "retry_jobs_by_filter",
        { filter: { queue_name: "overloaded" }, max_count: 10 },
        caller_id
      )
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("blast_radius_exceeded")
    end
  end

  context "when action is unknown" do
    it "returns denied with reason action_not_allowed" do
      result = pipeline.call("drop_database", {}, caller_id)
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("action_not_allowed")
    end
  end

  context "when params fail validation" do
    it "returns denied with reason parameter_validation_failed" do
      result = pipeline.call("inspect_job", { job_id: "../../etc/passwd" }, caller_id)
      expect(result.status).to eq(:denied)
      expect(result.metadata[:reason]).to eq("parameter_validation_failed")
    end
  end
end

# rubocop:enable RSpec/DescribeClass
