# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Collector::Privacy::Filter do
  subject(:filter) { described_class.new }

  describe "forbidden field names" do
    described_class::FORBIDDEN_FIELD_NAMES.each do |field_name|
      it "strips forbidden metadata field '#{field_name}'" do
        event = valid_action_completed_event.merge(
          metadata: { category: "jobs", field_name.to_sym => "smuggled_value" }
        )
        result = filter.filter(event)
        expect(result[:metadata].keys).not_to include(field_name.to_sym)
      end
    end

    it "strips forbidden fields even when mixed with allowed fields" do
      event = valid_action_completed_event.merge(
        metadata: { category: "jobs", params: "secret", operation: "retry", backtrace: "/app/lib" }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to eq(category: "jobs", operation: "retry")
    end

    it "strips forbidden fields from string-keyed metadata" do
      event = valid_action_completed_event.merge(
        metadata: { "category" => "jobs", "params" => "secret", "nonce" => "abc123" }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to eq(category: "jobs")
    end
  end

  describe "metadata value type validation" do
    it "allows String values" do
      event = valid_action_completed_event.merge(metadata: { category: "jobs" })
      result = filter.filter(event)
      expect(result[:metadata][:category]).to eq("jobs")
    end

    it "allows Integer values" do
      event = valid_rate_limit_checked_event.merge(metadata: { current_count: 7, limit: 10, window_seconds: 60 })
      result = filter.filter(event)
      expect(result[:metadata][:current_count]).to eq(7)
    end

    it "allows Float values" do
      event = valid_action_completed_event.merge(metadata: { category: 1.5 })
      result = filter.filter(event)
      expect(result[:metadata][:category]).to eq(1.5)
    end

    it "allows Boolean values" do
      event = valid_action_completed_event.merge(metadata: { confirmation_used: true })
      result = filter.filter(event)
      expect(result[:metadata][:confirmation_used]).to be(true)
    end

    it "allows nil values" do
      event = valid_action_completed_event.merge(metadata: { category: nil })
      result = filter.filter(event)
      expect(result[:metadata]).to have_key(:category)
    end

    it "rejects Hash values in metadata (prevents nested smuggling)" do
      event = valid_action_completed_event.merge(
        metadata: { category: "jobs", operation: { nested: "smuggled" } }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to eq(category: "jobs")
    end

    it "rejects Array values in metadata (prevents nested smuggling)" do
      event = valid_action_completed_event.merge(
        metadata: { category: "jobs", operation: %w[smuggled data] }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to eq(category: "jobs")
    end
  end

  describe "defense in depth" do
    it "applies forbidden field stripping before allowlist filtering" do
      event = valid_action_completed_event.merge(
        metadata: { params: "secret", category: "jobs" }
      )
      result = filter.filter(event)
      expect(result[:metadata].keys).to contain_exactly(:category)
    end

    it "applies value type validation after key filtering" do
      event = valid_action_completed_event.merge(
        metadata: { category: { nested: "smuggled" }, operation: "retry" }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to eq(operation: "retry")
    end

    it "handles event with all forbidden fields — returns empty metadata" do
      event = valid_action_completed_event.merge(
        metadata: { params: "x", backtrace: "y", nonce: "z", jid: "123" }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to be_empty
    end

    it "handles event with only complex-typed allowed values — returns empty metadata" do
      event = valid_action_completed_event.merge(
        metadata: { category: [1, 2, 3], operation: { a: "b" } }
      )
      result = filter.filter(event)
      expect(result[:metadata]).to be_empty
    end
  end
end
