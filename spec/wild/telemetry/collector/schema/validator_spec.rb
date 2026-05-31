# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::Telemetry::Collector::Schema::Validator do
  subject(:validator) { described_class.new }

  delegate :validate, to: :validator

  describe "with a valid action.completed event" do
    it "returns [true, []]" do
      valid, errors = validate(valid_action_completed_event)
      expect(valid).to be(true)
      expect(errors).to be_empty
    end
  end

  describe "with a valid gate.evaluated event" do
    it "returns [true, []]" do
      valid, errors = validate(valid_gate_evaluated_event)
      expect(valid).to be(true)
      expect(errors).to be_empty
    end
  end

  describe "with a valid rate_limit.checked event" do
    it "returns [true, []]" do
      valid, errors = validate(valid_rate_limit_checked_event)
      expect(valid).to be(true)
      expect(errors).to be_empty
    end
  end

  describe "when event_type is missing" do
    it "returns invalid with a descriptive error" do
      event = valid_action_completed_event.except(:event_type)
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/event_type/))
    end
  end

  describe "when timestamp is missing" do
    it "returns invalid with a descriptive error" do
      event = valid_action_completed_event.except(:timestamp)
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/timestamp/))
    end
  end

  describe "when caller_id is missing" do
    it "returns invalid with a descriptive error" do
      event = valid_action_completed_event.except(:caller_id)
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/caller_id/))
    end
  end

  describe "when action is missing" do
    it "returns invalid with a descriptive error" do
      event = valid_action_completed_event.except(:action)
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/action/))
    end
  end

  describe "when outcome is missing" do
    it "returns invalid with a descriptive error" do
      event = valid_action_completed_event.except(:outcome)
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/outcome/))
    end
  end

  describe "with an invalid event_type" do
    it "returns invalid with an event_type error" do
      event = valid_action_completed_event.merge(event_type: "unknown.event")
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/event_type/))
    end
  end

  describe "with an invalid outcome" do
    it "returns invalid with an outcome error" do
      event = valid_action_completed_event.merge(outcome: "approved")
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/outcome/))
    end
  end

  describe "with a non-ISO8601 timestamp" do
    it "returns invalid with a timestamp format error" do
      event = valid_action_completed_event.merge(timestamp: "19-03-2026 14:30:00")
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/timestamp/))
    end
  end

  describe "with a non-numeric duration_ms" do
    it "returns invalid with a duration_ms error" do
      event = valid_action_completed_event.merge(duration_ms: "fast")
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/duration_ms/))
    end
  end

  describe "with non-Hash metadata" do
    it "returns invalid with a metadata error" do
      event = valid_action_completed_event.merge(metadata: %w[tag1 tag2])
      valid, errors = validate(event)
      expect(valid).to be(false)
      expect(errors).to include(a_string_matching(/metadata/))
    end
  end

  describe "with nil duration_ms" do
    it "treats nil duration_ms as valid (optional field)" do
      event = valid_action_completed_event.merge(duration_ms: nil)
      valid, errors = validate(event)
      expect(valid).to be(true)
      expect(errors).to be_empty
    end
  end

  describe "with nil metadata" do
    it "treats nil metadata as valid (optional field)" do
      event = valid_action_completed_event.merge(metadata: nil)
      valid, errors = validate(event)
      expect(valid).to be(true)
      expect(errors).to be_empty
    end
  end
end
