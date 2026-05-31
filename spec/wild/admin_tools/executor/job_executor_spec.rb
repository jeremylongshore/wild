# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::JobExecutor do
  let(:adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:executor) { described_class.new }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = adapter
      c.cache_adapter = Wild::AdminTools::TestSupport::TestCacheAdapter.new
      c.flag_adapter = Wild::AdminTools::TestSupport::TestFlagAdapter.new
    end
    adapter.seed_job("job-1", status: "dead", queue: "default", error_class: "RuntimeError")
    adapter.seed_job("job-2", status: "dead", queue: "critical", error_class: "TimeoutError")
    adapter.seed_queue("default", size: 5)
    adapter.seed_queue("critical", size: 2)
  end

  describe "read actions" do
    it_behaves_like "a read action", "inspect_job", { job_id: "job-1" }
    it_behaves_like "a read action", "list_failed_jobs", {}
    it_behaves_like "a read action", "list_queues", {}

    describe "inspect_job preview data" do
      it "includes job details" do
        result = executor.preview("inspect_job", { job_id: "job-1" })
        expect(result.data[:job]).to include(job_id: "job-1", status: "dead")
      end
    end

    describe "list_failed_jobs with filters" do
      it "filters by error_class" do
        result = executor.preview("list_failed_jobs", { error_class: "RuntimeError" })
        expect(result.data[:jobs].size).to eq(1)
        expect(result.data[:jobs].first[:error_class]).to eq("RuntimeError")
      end
    end

    describe "list_queues" do
      it "returns all queues" do
        result = executor.preview("list_queues", {})
        expect(result.data[:queues].size).to eq(2)
      end
    end
  end

  describe "mutating actions" do
    it_behaves_like "a mutating action", "retry_job", "mutate", { job_id: "job-1" }
    it_behaves_like "a mutating action", "discard_job", "mutate_destructive", { job_id: "job-1" }

    describe "retry_job" do
      it "changes job status to enqueued" do
        executor.execute("retry_job", { job_id: "job-1" })
        job = adapter.find_job("job-1")
        expect(job[:status]).to eq("enqueued")
      end
    end

    describe "discard_job" do
      it "changes job status to discarded" do
        executor.execute("discard_job", { job_id: "job-1" })
        job = adapter.find_job("job-1")
        expect(job[:status]).to eq("discarded")
      end
    end

    describe "retry_jobs_by_filter" do
      it_behaves_like "a safe preview", "retry_jobs_by_filter", { filter: { queue_name: "default" } }

      it "returns estimated_affected count in preview" do
        result = executor.preview("retry_jobs_by_filter", { filter: { queue_name: "default" } })
        expect(result.data[:estimated_affected]).to eq(1)
      end

      it "retries matching jobs" do
        result = executor.execute("retry_jobs_by_filter", { filter: { error_class: "RuntimeError" } })
        expect(result.data[:retried_count]).to eq(1)
      end
    end

    describe "discard_jobs_by_filter" do
      it_behaves_like "a safe preview", "discard_jobs_by_filter", { filter: { queue_name: "critical" } }

      it "discards matching jobs" do
        result = executor.execute("discard_jobs_by_filter", { filter: { error_class: "TimeoutError" } })
        expect(result.data[:discarded_count]).to eq(1)
      end
    end
  end

  describe "state capture" do
    it "captures before/after snapshots on execute" do
      result = executor.execute("retry_job", { job_id: "job-1" })
      expect(result.before_snapshot).to include(job_id: "job-1", status: "dead")
      expect(result.after_snapshot).to include(job_id: "job-1", status: "enqueued")
    end
  end
end
