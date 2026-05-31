# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Audit::Record do
  subject(:record) do
    described_class.new(
      caller_id: "user_123",
      action: "retry_job",
      outcome: "success"
    )
  end

  describe "defaults" do
    it "generates a UUID id" do
      expect(record.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "sets timestamp to ISO8601" do
      expect(record.timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "defaults category to unknown" do
      expect(record.category).to eq("unknown")
    end

    it "defaults parameters to empty hash" do
      expect(record.parameters).to eq({})
    end

    it "defaults phase to execute" do
      expect(record.phase).to eq("execute")
    end

    it "defaults gate_result to not_checked" do
      expect(record.gate_result).to eq("not_checked")
    end

    it "defaults server_version to current VERSION" do
      expect(record.server_version).to eq(Wild::VERSION)
    end

    it "defaults snapshots to nil" do
      expect(record.before_snapshot).to be_nil
      expect(record.after_snapshot).to be_nil
    end
  end

  describe "immutability" do
    it "is frozen" do
      expect(record).to be_frozen
    end
  end

  describe "predicates" do
    it "#success? returns true for success outcome" do
      expect(record).to be_success
    end

    it "#denied? returns true for denied outcome" do
      denied = described_class.new(caller_id: "x", action: "a", outcome: "denied")
      expect(denied).to be_denied
    end

    it "#error? returns true for error outcome" do
      errored = described_class.new(caller_id: "x", action: "a", outcome: "error")
      expect(errored).to be_error
    end

    it "#preview? returns true for preview outcome" do
      preview = described_class.new(caller_id: "x", action: "a", outcome: "preview")
      expect(preview).to be_preview
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      h = record.to_h
      expect(h).to include(
        id: record.id,
        caller_id: "user_123",
        action: "retry_job",
        outcome: "success",
        gate_result: "not_checked",
        server_version: Wild::VERSION
      )
    end
  end

  describe "with full fields" do
    subject(:full) do
      described_class.new(
        caller_id: "admin_1", action: "discard_job", category: "background_jobs",
        parameters: { job_id: "123" }, phase: "execute", confirmation_nonce: "wnc_abc123",
        gate_result: "allowed", outcome: "success", denial_reason: nil,
        before_snapshot: { status: "failed" }, after_snapshot: { status: "discarded" },
        duration_ms: 42.5, error_message: nil
      )
    end

    it "preserves category and snapshots" do
      expect(full.category).to eq("background_jobs")
      expect(full.before_snapshot).to eq({ status: "failed" })
      expect(full.after_snapshot).to eq({ status: "discarded" })
      expect(full.duration_ms).to eq(42.5)
    end
  end
end
