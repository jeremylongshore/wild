# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Models::Transcript do
  subject(:transcript) { make_transcript }

  describe "#initialize" do
    it "stores source_type as symbol" do
      expect(transcript.source_type).to eq(:generic)
    end

    it "stores source_id as frozen string" do
      expect(transcript.source_id).to eq("test-001")
      expect(transcript.source_id).to be_frozen
    end

    it "freezes turns array" do
      expect(transcript.turns).to be_frozen
    end

    it "freezes intents array" do
      expect(transcript.intents).to be_frozen
    end

    it "freezes tool_references array" do
      expect(transcript.tool_references).to be_frozen
    end

    it "freezes metadata hash" do
      expect(transcript.metadata).to be_frozen
    end

    it "defaults created_at to current time when nil" do
      t = described_class.new(source_type: :generic, source_id: "x")
      expect(t.created_at).to be_a(Time)
    end

    it "raises ArgumentError for non-Symbol source_type" do
      expect do
        described_class.new(source_type: "generic", source_id: "x")
      end.to raise_error(ArgumentError, /source_type/)
    end

    it "raises ArgumentError for empty source_id" do
      expect do
        described_class.new(source_type: :generic, source_id: "")
      end.to raise_error(ArgumentError, /source_id/)
    end

    it "raises ArgumentError for non-Array turns" do
      expect do
        described_class.new(source_type: :generic, source_id: "x", turns: "bad")
      end.to raise_error(ArgumentError, /turns/)
    end

    it "raises ArgumentError for non-Hash metadata" do
      expect do
        described_class.new(source_type: :generic, source_id: "x", metadata: [])
      end.to raise_error(ArgumentError, /metadata/)
    end
  end

  describe "#turn_count" do
    it "returns the number of turns" do
      expect(transcript.turn_count).to eq(2)
    end
  end

  describe "#intent_count" do
    it "returns 0 when no intents" do
      expect(transcript.intent_count).to eq(0)
    end

    it "returns count when intents present" do
      t = make_transcript(intents: [make_intent])
      expect(t.intent_count).to eq(1)
    end
  end

  describe "#tool_reference_count" do
    it "returns 0 when no tool references" do
      expect(transcript.tool_reference_count).to eq(0)
    end

    it "returns count when tool refs present" do
      t = make_transcript(tool_references: [make_tool_reference])
      expect(t.tool_reference_count).to eq(1)
    end
  end

  describe "#to_h" do
    it "includes all top-level keys" do
      h = transcript.to_h
      expect(h).to include(:source_type, :source_id, :created_at, :turn_count,
                           :intent_count, :tool_reference_count, :turns, :intents,
                           :tool_references, :metadata)
    end

    it "serializes created_at as iso8601 string" do
      expect(transcript.to_h[:created_at]).to be_a(String)
    end

    it "serializes turns as array of hashes" do
      expect(transcript.to_h[:turns]).to all(be_a(Hash))
    end
  end
end
