# frozen_string_literal: true

RSpec.describe Wild::Hooks::Audit::Logger do
  subject(:logger) { described_class.new(config: config) }

  let(:config) { Wild.config.hooks }
  let(:handler) { build_handler }
  let(:result)  { build_result(handler: handler) }

  describe "#record" do
    it "returns a HookEvent" do
      event = logger.record(result, { tool: "bash" })
      expect(event).to be_a(Wild::Hooks::Models::HookEvent)
    end

    it "stores the event in the trail" do
      logger.record(result, {})
      expect(logger.trail.count).to eq(1)
    end

    it "includes context summary in the event" do
      event = logger.record(result, { tool: "bash", user: "alice" })
      expect(event.context_summary).to include("tool")
      expect(event.context_summary).to include("bash")
    end

    it "records outcome from result" do
      event = logger.record(result, {})
      expect(event.outcome).to eq(:success)
    end

    it "records error message for error results" do
      err = RuntimeError.new("boom")
      error_result = build_result(handler: handler, outcome: :error, error: err)
      event = logger.record(error_result, {})
      expect(event.error_message).to eq("boom")
    end

    context "when audit logging is disabled" do
      before { config.enable_audit_logging = false }

      it "returns nil and does not store anything" do
        result = logger.record(build_result, {})
        expect(result).to be_nil
        expect(logger.trail.count).to eq(0)
      end
    end

    it "handles empty context gracefully" do
      event = logger.record(result, {})
      expect(event.context_summary).to eq("")
    end

    it "handles nil-handler result gracefully" do
      null_result = Wild::Hooks::Models::HookResult.new(handler: nil, outcome: :success,
                                                        duration_ms: 1.0)
      expect { logger.record(null_result, {}) }.not_to raise_error
    end

    context "with sensitive context values (f-l01-1)" do
      it "never writes a raw password into the trail entry" do
        event = logger.record(result, { password: "hunter2", tool: "bash" })

        expect(event.context_summary).not_to include("hunter2")
        expect(event.context_summary).to include("[REDACTED]")
      end

      it "never writes a raw api_key into the trail entry" do
        event = logger.record(result, { api_key: "sk-live-abc123" })

        expect(event.context_summary).not_to include("sk-live-abc123")
        expect(event.context_summary).to include("[REDACTED]")
      end

      it "never writes a raw token into the trail entry" do
        event = logger.record(result, { token: "eyJabc.def.ghi" })

        expect(event.context_summary).not_to include("eyJabc.def.ghi")
        expect(event.context_summary).to include("[REDACTED]")
      end

      it "routes context through a custom sanitizer when one is injected" do
        custom_sanitizer = Wild::Hooks::Audit::Sanitizer.new(redact_keys: %w[tool])
        custom_logger = described_class.new(config: config, sanitizer: custom_sanitizer)

        event = custom_logger.record(result, { tool: "bash" })

        expect(event.context_summary).to include("[REDACTED]")
        expect(event.context_summary).not_to include("bash")
      end

      it "never writes a raw password embedded in an error message into the trail entry" do
        err = RuntimeError.new("connection failed: password=hunter2")
        error_result = build_result(handler: handler, outcome: :error, error: err)

        event = logger.record(error_result, {})

        expect(event.error_message).not_to include("hunter2")
        expect(event.error_message).to include("[REDACTED]")
      end

      it "does not raise when the error's #message itself raises" do
        raising_error = RuntimeError.new
        allow(raising_error).to receive(:message).and_raise(StandardError, "boom")
        error_result = build_result(handler: handler, outcome: :error, error: raising_error)

        expect { logger.record(error_result, {}) }.not_to raise_error
      end
    end
  end

  describe "#trail" do
    it "returns a Trail instance" do
      expect(logger.trail).to be_a(Wild::Hooks::Audit::Trail)
    end
  end
end
