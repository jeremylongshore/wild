# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Audit::Recorder do
  subject(:recorder) { described_class.new(store: store) }

  let(:store) { Wild::AdminTools::Audit::MemoryStore.new }

  let(:success_result) do
    Wild::AdminTools::Result.new(
      status: :success,
      action: "retry_job",
      operation: "mutate",
      before_snapshot: { status: "failed" },
      after_snapshot: { status: "retrying" }
    )
  end

  let(:preview_result) do
    Wild::AdminTools::Result.new(
      status: :preview,
      action: "retry_job",
      operation: "mutate",
      metadata: { nonce: "wnc_abc", requires_confirmation: true }
    )
  end

  let(:denied_result) do
    Wild::AdminTools::Result.new(
      status: :denied,
      action: "retry_job",
      operation: "unknown",
      metadata: { reason: "rate_limited", retry_after_seconds: 30 }
    )
  end

  describe "#record" do
    context "with successful execution" do
      it "produces an audit record" do
        recorder.record(action_name: "retry_job", params: { job_id: "123" }, caller_id: "user_1") do
          success_result
        end

        expect(store.count).to eq(1)
        record = store.recent(limit: 1).first
        expect(record.outcome).to eq("success")
        expect(record.action).to eq("retry_job")
        expect(record.caller_id).to eq("user_1")
      end

      it "captures before/after snapshots from result" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.before_snapshot).to eq({ status: "failed" })
        expect(record.after_snapshot).to eq({ status: "retrying" })
      end

      it "records duration_ms" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.duration_ms).to be_a(Numeric)
        expect(record.duration_ms).to be >= 0
      end

      it "returns the original result" do
        result = recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          success_result
        end

        expect(result).to eq(success_result)
      end

      it "sanitizes parameters" do
        recorder.record(action_name: "retry_job", params: { password: "secret", queue: "low" }, caller_id: "user_1") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.parameters[:password]).to eq("[REDACTED]")
        expect(record.parameters[:queue]).to eq("low")
      end

      it "maps category from action name" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.category).to eq("background_jobs")
      end
    end

    context "with preview result" do
      it "records phase as preview" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          preview_result
        end

        record = store.recent(limit: 1).first
        expect(record.phase).to eq("preview")
        expect(record.outcome).to eq("preview")
      end
    end

    context "with denied result" do
      it "records denial with reason" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          denied_result
        end

        record = store.recent(limit: 1).first
        expect(record.phase).to eq("denied")
        expect(record.outcome).to eq("denied")
        expect(record.denial_reason).to eq("rate_limited")
      end
    end

    context "with an error" do
      before do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          raise StandardError, "boom"
        end
      rescue StandardError
        # expected
      end

      it "creates an audit record" do
        expect(store.count).to eq(1)
      end

      it "records error outcome and phase" do
        record = store.recent(limit: 1).first
        expect(record.outcome).to eq("error")
        expect(record.phase).to eq("error")
        expect(record.error_message).to eq("StandardError: boom")
      end

      it "re-raises the original error" do
        expect do
          recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
            raise StandardError, "boom"
          end
        end.to raise_error(StandardError, "boom")
      end
    end

    context "with nonce" do
      it "includes nonce in record" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1", nonce: "wnc_xyz") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.confirmation_nonce).to eq("wnc_xyz")
      end
    end

    context "with session_context" do
      it "extracts gate_result when available" do
        context_obj = Struct.new(:gate_result).new("allowed")

        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1", session_context: context_obj) do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.gate_result).to eq("allowed")
      end

      it "defaults to not_checked when session_context is nil" do
        recorder.record(action_name: "retry_job", params: {}, caller_id: "user_1") do
          success_result
        end

        record = store.recent(limit: 1).first
        expect(record.gate_result).to eq("not_checked")
      end
    end
  end
end
