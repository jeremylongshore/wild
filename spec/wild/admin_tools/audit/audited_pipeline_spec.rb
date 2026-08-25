# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Audit::AuditedPipeline do
  let(:audit_store) { Wild::AdminTools::Audit::MemoryStore.new }
  let(:recorder) { Wild::AdminTools::Audit::Recorder.new(store: audit_store) }
  let(:policy_config) { valid_policy_config }
  let(:pipeline) { Wild::AdminTools::Guard::Pipeline.new(policy_config: policy_config) }
  let(:audited) { described_class.new(pipeline: pipeline, recorder: recorder) }

  before do
    Wild::AdminTools.configure do |config|
      config.job_adapter = Wild::AdminTools::TestSupport::TestJobAdapter.new
      config.cache_adapter = Wild::AdminTools::TestSupport::TestCacheAdapter.new
      config.flag_adapter = Wild::AdminTools::TestSupport::TestFlagAdapter.new
    end

    job_executor = Wild::AdminTools::Executor::JobExecutor.new
    cache_executor = Wild::AdminTools::Executor::CacheExecutor.new
    flag_executor = Wild::AdminTools::Executor::FlagExecutor.new

    audited.register_executor(job_executor)
    audited.register_executor(cache_executor)
    audited.register_executor(flag_executor)
  end

  describe "#call" do
    context "with a read action" do
      before do
        Wild::AdminTools.configuration.job_adapter.seed_job(
          "job_1", status: "completed", queue: "default"
        )
      end

      it "produces an audit record for reads" do
        result = audited.call("inspect_job", { job_id: "job_1" }, "caller_1")

        expect(result.status).to eq(:success)
        expect(audit_store.count).to eq(1)

        record = audit_store.recent(limit: 1).first
        expect(record.outcome).to eq("success")
        expect(record.action).to eq("inspect_job")
        expect(record.caller_id).to eq("caller_1")
      end
    end

    context "with a mutation (preview phase)" do
      before do
        Wild::AdminTools.configuration.job_adapter.seed_job(
          "job_1", status: "failed", queue: "critical"
        )
      end

      it "produces an audit record for preview" do
        result = audited.call("retry_job", { job_id: "job_1" }, "caller_1")

        expect(result.status).to eq(:preview)
        expect(audit_store.count).to eq(1)

        record = audit_store.recent(limit: 1).first
        expect(record.outcome).to eq("preview")
        expect(record.phase).to eq("preview")
      end
    end

    context "with a denied action" do
      it "produces an audit record for unknown actions" do
        result = audited.call("nonexistent_action", {}, "caller_1")

        expect(result.status).to eq(:denied)
        expect(audit_store.count).to eq(1)

        record = audit_store.recent(limit: 1).first
        expect(record.outcome).to eq("denied")
        expect(record.denial_reason).to eq("action_not_allowed")
      end
    end

    context "with rate limiting" do
      before do
        Wild::AdminTools.configuration.job_adapter.seed_job(
          "job_1", status: "completed", queue: "default"
        )
      end

      it "produces audit records for rate-limited denials" do
        # Exhaust rate limit (inspect_job allows 60/minute)
        61.times do
          audited.call("inspect_job", { job_id: "job_1" }, "rate_test_caller")
        end

        records = audit_store.recent(limit: 100)
        denied_records = records.select(&:denied?)
        expect(denied_records).not_to be_empty
        expect(denied_records.first.denial_reason).to eq("rate_limited")
      end
    end

    context "with errors" do
      it "produces an audit record when executor raises" do
        # Call and rescue - the recorder captures errors before re-raising
        begin
          audited.call("inspect_job", { job_id: "missing" }, "caller_1")
        rescue StandardError
          # expected - adapter may raise for missing job
        end

        # Whether it raised or returned normally, there should be an audit record
        expect(audit_store.count).to be >= 1
      end
    end
  end

  describe "#register_executor" do
    it "delegates to the wrapped pipeline" do
      executor = Wild::AdminTools::Executor::JobExecutor.new

      expect { audited.register_executor(executor) }.not_to raise_error
    end
  end

  describe "no public reader for the internal guard chain (finding f-l10-4)" do
    it "does not expose a #two_phase reader at all" do
      # This confirms an unused PUBLIC handle is gone, not a security
      # boundary: any in-process object already holding a reference to
      # @pipeline (or an executor) is trusted code inside this gem's own
      # process, and could always reach TwoPhaseFlow/executor methods
      # directly via instance_variable_get regardless of what this class
      # delegates. See lib/wild/admin_tools.rb's trust-boundary note (wording
      # corrected, security-review follow-up on f-l10-4, PR #73).
      expect(audited).not_to respond_to(:two_phase)
      expect { audited.two_phase }.to raise_error(NoMethodError)
    end

    it "audits both phases of a destructive execution reached through the PUBLIC surface" do
      # Drives the documented repro path (NonceManager#generate, then
      # TwoPhaseFlow#confirm_and_execute) through AuditedPipeline#call, the
      # one sanctioned entry point (also reachable via Server::ToolHandler)
      # for both preview and confirm, instead of only asserting that a
      # private handle is unreachable. Every phase of a real destructive
      # execution must land in the audit trail (security-review follow-up on
      # f-l10-4, PR #73).
      Wild::AdminTools.configuration.job_adapter.seed_job("job_bypass", status: "failed", queue: "critical")

      preview = audited.call("discard_job", { job_id: "job_bypass" }, "caller_1")
      expect(preview.status).to eq(:preview)
      nonce = preview.metadata[:nonce]

      confirm = audited.call("discard_job", { job_id: "job_bypass" }, "caller_1", nonce: nonce)
      expect(confirm.status).to eq(:success)

      records = audit_store.recent(limit: 100)
      expect(records.map(&:phase)).to include("preview", "execute")
      expect(Wild::AdminTools.configuration.job_adapter.write_methods_called).not_to be_empty
    end
  end

  describe "#recorder" do
    it "exposes the recorder" do
      expect(audited.recorder).to eq(recorder)
    end
  end

  describe "no call bypasses audit" do
    before do
      Wild::AdminTools.configuration.job_adapter.seed_job(
        "job_1", status: "completed", queue: "default"
      )
      Wild::AdminTools.configuration.cache_adapter.seed_key("key_1", "value")
      Wild::AdminTools.configuration.flag_adapter.seed_flag("feature_x", enabled: true)
    end

    it "audits read operations" do
      audited.call("inspect_job", { job_id: "job_1" }, "caller_1")
      expect(audit_store.count).to eq(1)
    end

    it "audits denied operations" do
      audited.call("unknown_action", {}, "caller_1")
      expect(audit_store.count).to eq(1)
    end

    it "audits cache reads" do
      audited.call("inspect_cache_key", { cache_key: "key_1" }, "caller_1")
      expect(audit_store.count).to eq(1)
    end

    it "audits flag reads" do
      audited.call("read_flag", { flag_name: "feature_x" }, "caller_1")
      expect(audit_store.count).to eq(1)
    end
  end
end
