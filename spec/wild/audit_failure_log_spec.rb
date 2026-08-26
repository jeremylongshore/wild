# frozen_string_literal: true

RSpec.describe Wild::AuditFailureLog do
  after { Wild.reset_config! }

  it "writes a standardized line to the configured logger" do
    logger = instance_double(Logger, error: nil)
    Wild.configure { |config| config.audit_logger = logger }

    described_class.record(tag: "hooks", error: IOError.new("disk full"), detail: "sink failed")

    expect(logger).to have_received(:error)
      .with("[wild:hooks] sink failed: IOError: disk full")
  end

  it "falls back to stderr when no compatible logger is configured" do
    expect do
      described_class.record(tag: "telemetry", error: IOError.new("disk full"), detail: "store failed")
    end.to output(/\[wild:telemetry\] store failed: IOError: disk full/).to_stderr
  end

  it "never raises when the error message and configured logger both raise" do
    error = Class.new(StandardError) do
      def message = raise("message unavailable")
    end.new
    logger = instance_double(Logger)
    allow(logger).to receive(:error).and_raise("logger unavailable")
    Wild.configure { |config| config.audit_logger = logger }

    expect { described_class.record(tag: "hooks", error: error, detail: "sink failed") }.not_to raise_error
  end
end
