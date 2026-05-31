# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Normalization::IntentDetector do
  subject(:detector) { described_class.new }

  describe "#detect" do
    context "with intent-bearing turns" do
      it 'detects "I need to" phrase' do
        turns = [make_turn(role: :user, content: "I need to fix this bug")]
        intents = detector.detect(turns)
        expect(intents).not_to be_empty
      end

      it 'detects "Let me" phrase' do
        turns = [make_turn(role: :assistant, content: "Let me check the logs for you")]
        intents = detector.detect(turns)
        expect(intents).not_to be_empty
      end

      it "detects \"I can't find a tool for\" phrase" do
        turns = [make_turn(role: :assistant, content: "I can't find a tool for executing tests")]
        intents = detector.detect(turns)
        expect(intents).not_to be_empty
        expect(intents.first.confidence).to be >= 0.8
      end

      it "detects \"There's no way to\" phrase" do
        turns = [make_turn(role: :assistant, content: "There's no way to run code directly")]
        intents = detector.detect(turns)
        expect(intents.first.confidence).to be >= 0.7
      end

      it 'detects "I will" phrase' do
        turns = [make_turn(role: :assistant, content: "I will analyze the data now")]
        intents = detector.detect(turns)
        expect(intents).not_to be_empty
      end

      it "includes source_turn_index in intent" do
        turns = [
          make_turn(role: :user, content: "hello"),
          make_turn(role: :assistant, content: "I need to find that file")
        ]
        intents = detector.detect(turns)
        expect(intents.first.source_turn_index).to eq(1)
      end
    end

    context "with tool-call content" do
      it "skips tool-use content turns" do
        turns = [make_turn(role: :assistant, content: "[tool_use] inspect_routes({})")]
        intents = detector.detect(turns)
        expect(intents).to be_empty
      end

      it "skips mcp:request content" do
        turns = [make_turn(role: :user, content: "[mcp:request] tools/call foo({})")]
        intents = detector.detect(turns)
        expect(intents).to be_empty
      end
    end

    context "with tool role turns" do
      it "skips tool role turns" do
        turns = [make_turn(role: :tool, content: "I need to show you the results")]
        intents = detector.detect(turns)
        expect(intents).to be_empty
      end
    end

    context "with threshold filtering" do
      it "filters out intents below threshold" do
        Wild.configure { |c| c.telemetry.pipeline.intent_confidence_threshold = 0.99 }
        turns = [make_turn(role: :user, content: "I need to do something")]
        intents = detector.detect(turns, config: Wild.config.telemetry.pipeline)
        expect(intents).to be_empty
      end

      it "includes intents at or above threshold" do
        Wild.configure { |c| c.telemetry.pipeline.intent_confidence_threshold = 0.0 }
        turns = [make_turn(role: :user, content: "I need to do something")]
        intents = detector.detect(turns, config: Wild.config.telemetry.pipeline)
        expect(intents).not_to be_empty
      end
    end

    context "with empty or plain turns" do
      it "returns empty array for empty turns array" do
        expect(detector.detect([])).to eq([])
      end

      it "skips empty content turns" do
        turns = [make_turn(role: :user, content: "")]
        expect(detector.detect(turns)).to eq([])
      end

      it "does not detect intent in plain sentences without markers" do
        turns = [make_turn(role: :user, content: "The weather is nice today")]
        expect(detector.detect(turns)).to be_empty
      end
    end

    it "raises NormalizationError for non-Array input" do
      expect { detector.detect("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::NormalizationError)
    end

    it "returns Intent objects" do
      turns = [make_turn(role: :user, content: "I need to debug this")]
      intents = detector.detect(turns)
      expect(intents).to all(be_a(Wild::Telemetry::Pipeline::Models::Intent))
    end

    it "returns at most one intent per turn" do
      turns = [make_turn(role: :assistant, content: "I need to check. Let me try. I will do it.")]
      intents = detector.detect(turns)
      turn_indices = intents.map(&:source_turn_index)
      expect(turn_indices.uniq.size).to eq(turn_indices.size)
    end
  end
end
