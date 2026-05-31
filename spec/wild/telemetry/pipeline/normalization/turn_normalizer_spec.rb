# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Normalization::TurnNormalizer do
  subject(:normalizer) { described_class.new }

  describe "#normalize" do
    context "with content within length limit" do
      it "returns unchanged content" do
        turns = [make_turn(content: "short content")]
        result = normalizer.normalize(turns)
        expect(result.first.content).to eq("short content")
      end
    end

    context "with content exceeding max_turn_content_length" do
      it "truncates content to configured max" do
        long = "x" * 20_000
        turns = [make_turn(content: long)]

        Wild.configure { |c| c.telemetry.pipeline.max_turn_content_length = 100 }
        result = normalizer.normalize(turns, config: Wild.config.telemetry.pipeline)
        expect(result.first.content.length).to eq(100)
      end
    end

    context "with too many turns" do
      it "truncates to max_turns_per_transcript" do
        turns = 50.times.map { |i| make_turn(content: "turn #{i}") }
        Wild.configure { |c| c.telemetry.pipeline.max_turns_per_transcript = 10 }
        result = normalizer.normalize(turns, config: Wild.config.telemetry.pipeline)
        expect(result.size).to eq(10)
      end

      it "keeps the first N turns" do
        turns = 5.times.map { |i| make_turn(content: "turn #{i}") }
        Wild.configure { |c| c.telemetry.pipeline.max_turns_per_transcript = 3 }
        result = normalizer.normalize(turns, config: Wild.config.telemetry.pipeline)
        expect(result.map(&:content)).to eq(["turn 0", "turn 1", "turn 2"])
      end
    end

    context "with turns within limit" do
      it "returns all turns when under max" do
        turns = 5.times.map { |i| make_turn(content: "turn #{i}") }
        result = normalizer.normalize(turns)
        expect(result.size).to eq(5)
      end
    end

    it "preserves role, timestamp, and metadata through normalization" do
      ts = Time.utc(2026, 1, 1)
      turn = make_turn(role: :assistant, content: "hi", timestamp: ts, metadata: { key: "val" })
      result = normalizer.normalize([turn])
      expect(result.first.role).to eq(:assistant)
      expect(result.first.timestamp).to eq(ts)
      expect(result.first.metadata).to eq({ key: "val" })
    end

    it "raises NormalizationError for non-Array input" do
      expect { normalizer.normalize("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::NormalizationError)
    end

    it "returns empty array for empty input" do
      expect(normalizer.normalize([])).to eq([])
    end
  end
end
