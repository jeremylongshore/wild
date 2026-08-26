# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::Adapters::SidekiqAdapter do
  # Plain `let`, not `subject(:adapter)`: this spec stubs the private
  # require_sidekiq! (the gem is not installed in this repo's bundle) which
  # RSpec/SubjectStub forbids on the declared subject.
  let(:adapter) { described_class.new }

  let(:fake_sidekiq) { Wild::AdminTools::TestSupport::FakeSidekiq }

  before do
    fake_sidekiq::DeadSet.reset!
    fake_sidekiq::Queue.reset!
    stub_const("Sidekiq::DeadSet", fake_sidekiq::DeadSet)
    stub_const("Sidekiq::Queue", fake_sidekiq::Queue)
    # The gem is not installed in this repo's bundle; require_sidekiq! would
    # LoadError on the real `require "sidekiq/api"` even with the constants
    # stubbed above, so the require itself is stubbed to a no-op the same
    # way a host app with the gem installed would just have it succeed.
    allow(adapter).to receive(:require_sidekiq!)
  end

  def seed_job(jid, queue: "default", error_class: "RuntimeError", job_class: "SomeJob")
    fake_sidekiq::DeadSet.jobs << fake_sidekiq::Job.new(
      jid, queue,
      {
        "error_class" => error_class, "error_message" => "boom", "failed_at" => 1,
        "retry_count" => 0, "enqueued_at" => nil, "created_at" => 1, "class" => job_class
      }
    )
  end

  it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::JobAdapter

  describe "#find_job" do
    it "returns nil for an unknown job id" do
      expect(adapter.find_job("ghost")).to be_nil
    end

    it "serializes a found job with error details" do
      seed_job("jid-1")
      result = adapter.find_job("jid-1")
      expect(result).to include(job_id: "jid-1", status: "dead", queue: "default", error_class: "RuntimeError")
    end
  end

  describe "#list_failed_jobs" do
    it "does not require any filter argument (abstract contract is **_options)" do
      expect { adapter.list_failed_jobs }.not_to raise_error
    end

    it "filters by queue_name and error_class" do
      seed_job("a", queue: "default", error_class: "Boom")
      seed_job("b", queue: "mailers", error_class: "Boom")
      result = adapter.list_failed_jobs(queue_name: "default")
      expect(result.pluck(:job_id)).to eq(["a"])
    end
  end

  describe "#list_queues" do
    it "maps queue entries to name/size/latency" do
      fake_sidekiq::Queue.all << fake_sidekiq::QueueEntry.new("default", 3, 1.5)
      expect(adapter.list_queues).to eq([{ name: "default", size: 3, latency: 1.5 }])
    end
  end

  describe "#count_matching_jobs" do
    it "counts across all filters with no required keyword" do
      seed_job("a")
      seed_job("b")
      expect(adapter.count_matching_jobs).to eq(2)
    end
  end

  describe "#retry_job!" do
    it "raises AdapterError for an unknown job" do
      expect { adapter.retry_job!("ghost") }.to raise_error(Wild::AdminTools::AdapterError, /not found/)
    end

    it "retries a found job" do
      seed_job("jid-1")
      result = adapter.retry_job!("jid-1")
      expect(result).to eq(job_id: "jid-1", retried: true)
    end
  end

  describe "#discard_jobs!" do
    it "discards up to max_count matching jobs and reports the count" do
      seed_job("a")
      seed_job("b")
      result = adapter.discard_jobs!(max_count: 1)
      expect(result[:discarded_count]).to eq(1)
    end
  end
end
