# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Models::TranscriptBatch do
  subject(:batch) { make_transcript_batch(count: 3) }

  describe "#initialize" do
    it "stores transcripts as frozen array" do
      expect(batch.transcripts).to be_frozen
    end

    it "stores metadata as frozen hash" do
      expect(batch.metadata).to be_frozen
    end

    it "defaults created_at to current time" do
      b = described_class.new
      expect(b.created_at).to be_a(Time)
    end

    it "raises ArgumentError for non-Array transcripts" do
      expect { described_class.new(transcripts: "bad") }
        .to raise_error(ArgumentError, /transcripts/)
    end

    it "raises ArgumentError for non-Hash metadata" do
      expect { described_class.new(metadata: "bad") }
        .to raise_error(ArgumentError, /metadata/)
    end
  end

  describe "#size" do
    it "returns the number of transcripts" do
      expect(batch.size).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns false for non-empty batch" do
      expect(batch.empty?).to be(false)
    end

    it "returns true for empty batch" do
      b = described_class.new(transcripts: [])
      expect(b.empty?).to be(true)
    end
  end

  describe "#total_turns" do
    it "sums turns across all transcripts" do
      expect(batch.total_turns).to eq(batch.transcripts.sum(&:turn_count))
    end
  end

  describe "#total_intents" do
    it "returns 0 when no intents" do
      expect(batch.total_intents).to eq(0)
    end
  end

  describe "#total_tool_references" do
    it "returns 0 when no tool references" do
      expect(batch.total_tool_references).to eq(0)
    end
  end

  describe "#source_types" do
    it "returns unique source types" do
      expect(batch.source_types).to eq([:generic])
    end
  end

  describe "#to_h" do
    it "includes all summary keys" do
      h = batch.to_h
      expect(h).to include(:created_at, :transcript_count, :total_turns,
                           :total_intents, :total_tool_references, :source_types,
                           :metadata, :transcripts)
    end

    it "transcript_count matches size" do
      expect(batch.to_h[:transcript_count]).to eq(3)
    end
  end
end
