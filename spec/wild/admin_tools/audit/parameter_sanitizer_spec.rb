# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Audit::ParameterSanitizer do
  subject(:sanitizer) { described_class.new }

  describe "#sanitize" do
    it "returns empty hash for nil" do
      expect(sanitizer.sanitize(nil)).to eq({})
    end

    it "returns empty hash for empty hash" do
      expect(sanitizer.sanitize({})).to eq({})
    end

    it "passes through safe keys unchanged" do
      params = { queue_name: "default", limit: 10, enabled: true }
      expect(sanitizer.sanitize(params)).to eq(params)
    end

    context "with redacted keys" do
      it "redacts password fields" do
        result = sanitizer.sanitize(password: "secret123")
        expect(result[:password]).to eq("[REDACTED]")
      end

      it "redacts token fields" do
        result = sanitizer.sanitize(api_token: "tok_abc")
        expect(result[:api_token]).to eq("[REDACTED]")
      end

      it "redacts email fields" do
        result = sanitizer.sanitize(email: "user@example.com")
        expect(result[:email]).to eq("[REDACTED]")
      end

      it "redacts keys containing the sensitive substring" do
        result = sanitizer.sanitize(user_password_hash: "abc123")
        expect(result[:user_password_hash]).to eq("[REDACTED]")
      end
    end

    context "with hashed keys" do
      it "hashes job_id values" do
        result = sanitizer.sanitize(job_id: "abc-123")
        expect(result[:job_id]).to match(/\A\[SHA256:[a-f0-9]{8}\]\z/)
      end

      it "hashes user_id values" do
        result = sanitizer.sanitize(user_id: "42")
        expect(result[:user_id]).to match(/\A\[SHA256:[a-f0-9]{8}\]\z/)
      end

      it "produces deterministic hashes" do
        r1 = sanitizer.sanitize(job_id: "same")
        r2 = sanitizer.sanitize(job_id: "same")
        expect(r1[:job_id]).to eq(r2[:job_id])
      end

      it "produces different hashes for different values" do
        r1 = sanitizer.sanitize(job_id: "a")
        r2 = sanitizer.sanitize(job_id: "b")
        expect(r1[:job_id]).not_to eq(r2[:job_id])
      end
    end

    context "with nested hashes" do
      it "recursively sanitizes nested hashes" do
        result = sanitizer.sanitize(filter: { email: "x@y.com", queue: "low" })
        expect(result[:filter][:email]).to eq("[REDACTED]")
        expect(result[:filter][:queue]).to eq("low")
      end
    end

    context "with mixed keys" do
      it "applies different strategies per key" do
        result = sanitizer.sanitize(
          job_id: "123",
          password: "secret",
          queue_name: "default"
        )

        expect(result[:job_id]).to match(/\A\[SHA256:/)
        expect(result[:password]).to eq("[REDACTED]")
        expect(result[:queue_name]).to eq("default")
      end
    end

    context "with custom key lists" do
      it "allows custom redact keys" do
        custom = described_class.new(redact_keys: %w[custom_secret], hash_keys: [])
        result = custom.sanitize(custom_secret: "val", other: "ok")
        expect(result[:custom_secret]).to eq("[REDACTED]")
        expect(result[:other]).to eq("ok")
      end
    end
  end
end
