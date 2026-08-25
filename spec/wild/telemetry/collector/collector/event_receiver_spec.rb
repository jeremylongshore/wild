# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::Telemetry::Collector::Collector::EventReceiver do
  subject(:receiver) { described_class.new(store: store) }

  let(:store) { Wild::Telemetry::Collector::Store::MemoryStore.new }

  describe "with a valid action.completed event" do
    it "returns an EventEnvelope" do
      result = receiver.receive(valid_action_completed_event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
    end

    it "sets the correct event_type on the returned envelope" do
      result = receiver.receive(valid_action_completed_event)
      expect(result.event_type).to eq("action.completed")
    end
  end

  describe "with a valid gate.evaluated event" do
    it "returns an EventEnvelope with the correct event_type" do
      result = receiver.receive(valid_gate_evaluated_event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
      expect(result.event_type).to eq("gate.evaluated")
    end
  end

  describe "with a valid rate_limit.checked event" do
    it "returns an EventEnvelope with the correct event_type" do
      result = receiver.receive(valid_rate_limit_checked_event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
      expect(result.event_type).to eq("rate_limit.checked")
    end
  end

  describe "storage on success" do
    it "stores the envelope in the store after receiving a valid event" do
      expect { receiver.receive(valid_action_completed_event) }.to change(store, :count).from(0).to(1)
    end

    it "the stored envelope matches the returned envelope" do
      result = receiver.receive(valid_action_completed_event)
      stored = store.recent(limit: 1).first
      expect(stored).to eq(result)
    end
  end

  describe "when a required field is missing" do
    it "returns nil for an event missing event_type" do
      event = valid_action_completed_event.except(:event_type)
      expect(receiver.receive(event)).to be_nil
    end

    it "returns nil for an event missing outcome" do
      event = valid_action_completed_event.except(:outcome)
      expect(receiver.receive(event)).to be_nil
    end
  end

  describe "when an invalid event is received" do
    it "does not store the invalid event" do
      event = valid_action_completed_event.except(:caller_id)
      receiver.receive(event)
      expect(store.count).to eq(0)
    end
  end

  describe "field stripping before storage" do
    it "strips forbidden top-level fields and still returns an envelope" do
      event = valid_action_completed_event.merge(secret_token: "abc123")
      result = receiver.receive(event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
      expect(result.to_h.keys).not_to include(:secret_token)
    end
  end

  describe "metadata stripping before storage" do
    it "strips unknown metadata keys and still returns an envelope" do
      event = valid_action_completed_event.merge(
        metadata: { category: "background_jobs", raw_params: { id: 1 } }
      )
      result = receiver.receive(event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
      expect(result.metadata.keys).not_to include(:raw_params)
      expect(result.metadata).to include(:category)
    end
  end

  describe "fire-and-forget: store raises an exception" do
    subject(:receiver) { described_class.new(store: failing_store) }

    let(:failing_store) do
      store = instance_double(Wild::Telemetry::Collector::Store::MemoryStore)
      allow(store).to receive(:append).and_raise(RuntimeError, "disk full")
      store
    end

    it "returns nil when the store raises" do
      result = receiver.receive(valid_action_completed_event)
      expect(result).to be_nil
    end

    it "does not propagate the store exception to the caller" do
      expect { receiver.receive(valid_action_completed_event) }.not_to raise_error
    end

    it "counts the storage failure distinctly from a validation reject (finding f-l02-3)" do
      expect { receiver.receive(valid_action_completed_event) }
        .to change(receiver, :storage_failure_count).from(0).to(1)
    end

    it "does not count a validation reject as a storage failure" do
      event = valid_action_completed_event.except(:outcome)
      expect { receiver.receive(event) }.not_to change(receiver, :storage_failure_count)
    end

    it "logs the storage failure to Wild.config.audit_logger when one is configured" do
      logger = instance_double(Logger, warn: nil)
      Wild.configure { |c| c.audit_logger = logger }

      receiver.receive(valid_action_completed_event)

      expect(logger).to have_received(:warn).with(a_string_matching(/disk full/))
    end

    it "does not raise when no audit_logger is configured" do
      expect(Wild.config.audit_logger).to be_nil
      expect { receiver.receive(valid_action_completed_event) }.not_to raise_error
    end

    it "does not raise when the configured audit_logger itself raises" do
      broken_logger = instance_double(Logger)
      allow(broken_logger).to receive(:warn).and_raise(RuntimeError, "log pipe closed")
      Wild.configure { |c| c.audit_logger = broken_logger }

      expect { receiver.receive(valid_action_completed_event) }.not_to raise_error
    end
  end

  describe "exception safety" do
    it "never raises for any input, including nil" do
      expect { receiver.receive(nil) }.not_to raise_error
    end

    it "never raises for a completely empty hash" do
      expect { receiver.receive({}) }.not_to raise_error
    end
  end

  describe "with string-keyed events" do
    it "accepts a string-keyed event and returns an EventEnvelope" do
      string_event = valid_action_completed_event.transform_keys(&:to_s)
      result = receiver.receive(string_event)
      expect(result).to be_a(Wild::Telemetry::Collector::Schema::EventEnvelope)
      expect(result.event_type).to eq("action.completed")
    end

    it "stores the envelope for a string-keyed valid event" do
      string_event = valid_action_completed_event.transform_keys(&:to_s)
      expect { receiver.receive(string_event) }.to change(store, :count).from(0).to(1)
    end
  end
end
