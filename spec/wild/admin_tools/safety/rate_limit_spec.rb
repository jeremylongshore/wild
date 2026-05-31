# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

RSpec.describe "Rate limit enforcement — adversarial safety" do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:tools) { Wild::AdminTools::Server::Tools }
  let(:cache_adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:flag_adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }
  let(:gate) { Wild::AdminTools::TestSupport::TestGate.new }
  let(:audit_store) { Wild::AdminTools::Audit::MemoryStore.new }

  let(:pipeline) do
    Wild::AdminTools::Server::ServerFactory.build_pipeline(
      gate: gate, policy_config: policy_config, audit_store: audit_store
    )
  end

  let(:server_context) do
    Wild::AdminTools::Server::ServerFactory.build_server_context(
      pipeline: pipeline, caller_id: "rate-limit-tester"
    )
  end

  let(:policy_config) { full_policy_config }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
    job_adapter.seed_job("job-1")
  end

  after { nonce_store.stop_sweep! }

  describe "per-action rate limit (retry_job: 10/minute)" do
    it "allows exactly 10 calls at the limit" do
      10.times do
        resp = tools::ManageBackgroundJobs.call(
          action: "retry_job", job_id: "job-1", server_context: server_context
        )
        expect(resp.structured_content[:status]).to eq("preview")
      end
    end

    it "denies the 11th call with rate_limited and retry_after" do
      10.times do
        tools::ManageBackgroundJobs.call(
          action: "retry_job", job_id: "job-1", server_context: server_context
        )
      end
      response = tools::ManageBackgroundJobs.call(
        action: "retry_job", job_id: "job-1", server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("rate_limited")
      expect(body[:retry_after_seconds]).to be_a(Numeric)
    end

    it "produces no adapter writes after rate-limit denial" do
      10.times do
        tools::ManageBackgroundJobs.call(
          action: "retry_job", job_id: "job-1", server_context: server_context
        )
      end
      tools::ManageBackgroundJobs.call(
        action: "retry_job", job_id: "job-1", server_context: server_context
      )
      expect(job_adapter.write_methods_called).to be_empty
    end
  end

  describe "cross-caller isolation" do
    it "does not share per-action limits between callers" do
      10.times do
        tools::ManageBackgroundJobs.call(
          action: "retry_job", job_id: "job-1", server_context: server_context
        )
      end
      other_context = Wild::AdminTools::Server::ServerFactory.build_server_context(
        pipeline: pipeline, caller_id: "other-caller"
      )
      resp = tools::ManageBackgroundJobs.call(
        action: "retry_job", job_id: "job-1", server_context: other_context
      )
      expect(resp.structured_content[:status]).to eq("preview")
    end
  end

  describe "global read rate limit" do
    let(:policy_config) do
      hash = full_policy_hash
      hash["global_rate_limits"]["all_reads"] = "5/minute"
      Wild::AdminTools::Guard::PolicyConfig.from_hash(hash)
    end

    it "denies reads exceeding the global limit" do
      5.times do
        tools::ManageBackgroundJobs.call(
          action: "inspect_job", job_id: "job-1", server_context: server_context
        )
      end
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("rate_limited")
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
