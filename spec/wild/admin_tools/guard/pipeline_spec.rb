# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Guard::Pipeline do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:cache_adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:flag_adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }

  let(:pipeline) do
    described_class.new(policy_config: valid_policy_config).tap do |p|
      p.register_executor(Wild::AdminTools::Executor::JobExecutor.new)
      p.register_executor(Wild::AdminTools::Executor::CacheExecutor.new)
      p.register_executor(Wild::AdminTools::Executor::FlagExecutor.new)
    end
  end

  let(:caller_id) { "operator-1" }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
    job_adapter.seed_job("job-1")
    cache_adapter.seed_key("cache:key1", "value1")
    flag_adapter.seed_flag("my_flag")
  end

  after { pipeline.two_phase.nonce_manager.store.stop_sweep! }

  describe "#call" do
    context "when action is a read" do
      it "returns success directly without requiring a nonce" do
        result = pipeline.call("inspect_job", { job_id: "job-1" }, caller_id)
        expect(result.status).to eq(:success)
      end
    end

    context "when action is unknown" do
      it "returns denied with reason action_not_allowed" do
        result = pipeline.call("nuke_everything", {}, caller_id)
        expect(result.status).to eq(:denied)
        expect(result.metadata[:reason]).to eq("action_not_allowed")
      end
    end

    context "when params are invalid" do
      it "returns denied with reason parameter_validation_failed" do
        result = pipeline.call("inspect_job", { job_id: "!invalid!" }, caller_id)
        expect(result.status).to eq(:denied)
        expect(result.metadata[:reason]).to eq("parameter_validation_failed")
      end
    end

    context "when action is a mutation without a nonce" do
      it "returns preview with a nonce in metadata" do
        result = pipeline.call("retry_job", { job_id: "job-1" }, caller_id)
        expect(result.status).to eq(:preview)
        expect(result.metadata[:nonce]).to start_with("wnc_")
      end
    end

    context "when action is a mutation with a valid nonce" do
      it "returns success" do
        preview = pipeline.call("retry_job", { job_id: "job-1" }, caller_id)
        nonce = preview.metadata[:nonce]
        result = pipeline.call("retry_job", { job_id: "job-1" }, caller_id, nonce: nonce)
        expect(result.status).to eq(:success)
      end
    end

    context "when caller is rate limited" do
      it "returns denied with reason rate_limited" do
        11.times { pipeline.call("retry_job", { job_id: "job-1" }, caller_id) }
        result = pipeline.call("retry_job", { job_id: "job-1" }, caller_id)
        expect(result.status).to eq(:denied)
        expect(result.metadata[:reason]).to eq("rate_limited")
      end
    end
  end
end
