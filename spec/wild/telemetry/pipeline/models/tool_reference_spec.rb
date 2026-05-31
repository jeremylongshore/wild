# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Models::ToolReference do
  subject(:ref) do
    described_class.new(name: "inspect_connection", action: :called, outcome: :success, turn_index: 3)
  end

  describe "#initialize" do
    it "stores name, action, outcome, turn_index" do
      expect(ref.name).to eq("inspect_connection")
      expect(ref.action).to eq(:called)
      expect(ref.outcome).to eq(:success)
      expect(ref.turn_index).to eq(3)
    end

    it "accepts nil outcome" do
      r = described_class.new(name: "some_tool", action: :mentioned, turn_index: 0)
      expect(r.outcome).to be_nil
    end

    it "accepts all valid actions" do
      described_class::VALID_ACTIONS.each do |action|
        r = described_class.new(name: "tool", action: action, turn_index: 0)
        expect(r.action).to eq(action)
      end
    end

    it "coerces string action to symbol" do
      r = described_class.new(name: "tool", action: "called", turn_index: 0)
      expect(r.action).to eq(:called)
    end

    it "accepts all valid outcomes" do
      described_class::VALID_OUTCOMES.each do |outcome|
        r = described_class.new(name: "tool", action: :called, outcome: outcome, turn_index: 0)
        expect(r.outcome).to eq(outcome)
      end
    end

    it "raises ArgumentError for empty name" do
      expect { described_class.new(name: "", action: :called, turn_index: 0) }
        .to raise_error(ArgumentError, /name/)
    end

    it "raises ArgumentError for invalid action" do
      expect { described_class.new(name: "tool", action: :unknown_action, turn_index: 0) }
        .to raise_error(ArgumentError, /action/)
    end

    it "raises ArgumentError for invalid outcome" do
      expect { described_class.new(name: "tool", action: :called, outcome: :bad, turn_index: 0) }
        .to raise_error(ArgumentError, /outcome/)
    end

    it "raises ArgumentError for negative turn_index" do
      expect { described_class.new(name: "tool", action: :called, turn_index: -1) }
        .to raise_error(ArgumentError, /turn_index/)
    end

    it "raises ArgumentError for non-integer turn_index" do
      expect { described_class.new(name: "tool", action: :called, turn_index: 1.0) }
        .to raise_error(ArgumentError, /turn_index/)
    end
  end

  describe "#to_h" do
    it "returns a complete hash" do
      h = ref.to_h
      expect(h[:name]).to eq("inspect_connection")
      expect(h[:action]).to eq(:called)
      expect(h[:outcome]).to eq(:success)
      expect(h[:turn_index]).to eq(3)
    end

    it "includes nil outcome in hash" do
      r = described_class.new(name: "tool", action: :mentioned, turn_index: 0)
      expect(r.to_h[:outcome]).to be_nil
    end
  end
end
