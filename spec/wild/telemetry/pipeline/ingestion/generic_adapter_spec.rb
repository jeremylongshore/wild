# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Ingestion::GenericAdapter do
  subject(:adapter) { described_class.new }

  describe "#parse" do
    context "with turns-keyed JSON" do
      it "returns an array of Transcripts" do
        result = adapter.parse(generic_json)
        expect(result).to all(be_a(Wild::Telemetry::Pipeline::Models::Transcript))
      end

      it "sets source_type to :generic" do
        expect(adapter.parse(generic_json).first.source_type).to eq(:generic)
      end

      it "parses user and assistant turns" do
        result = adapter.parse(generic_json)
        roles = result.first.turns.map(&:role)
        expect(roles).to include(:user, :assistant)
      end
    end

    context "with messages-keyed JSON" do
      it "parses messages array" do
        data = JSON.generate({ "messages" => default_generic_turns })
        result = adapter.parse(data)
        expect(result.first.turn_count).to eq(2)
      end
    end

    context "with bare JSON array" do
      it "parses array of turn objects" do
        data = JSON.generate(default_generic_turns)
        result = adapter.parse(data)
        expect(result.first.turn_count).to eq(2)
      end
    end

    context "with role aliases" do
      it "maps human to :user" do
        data = JSON.generate({ "turns" => [{ "role" => "human", "content" => "hi" }] })
        result = adapter.parse(data)
        expect(result.first.turns.first.role).to eq(:user)
      end

      it "maps ai to :assistant" do
        data = JSON.generate({ "turns" => [{ "role" => "ai", "content" => "hi" }] })
        result = adapter.parse(data)
        expect(result.first.turns.first.role).to eq(:assistant)
      end

      it "maps bot to :assistant" do
        data = JSON.generate({ "turns" => [{ "role" => "bot", "content" => "hi" }] })
        result = adapter.parse(data)
        expect(result.first.turns.first.role).to eq(:assistant)
      end

      it "maps function to :tool" do
        data = JSON.generate({ "turns" => [{ "role" => "function", "content" => "result" }] })
        result = adapter.parse(data)
        expect(result.first.turns.first.role).to eq(:tool)
      end
    end

    context "with timestamps" do
      it "parses timestamp when present" do
        ts = "2026-03-19T14:00:00Z"
        data = JSON.generate({ "turns" => [{ "role" => "user", "content" => "hi", "timestamp" => ts }] })
        result = adapter.parse(data)
        expect(result.first.turns.first.timestamp).not_to be_nil
      end
    end

    it "skips entries with unknown roles" do
      data = JSON.generate({ "turns" => [
                             { "role" => "robot", "content" => "beep" },
                             { "role" => "user", "content" => "hi" }
                           ] })
      result = adapter.parse(data)
      expect(result.first.turn_count).to eq(1)
    end

    it "skips non-Hash entries" do
      data = JSON.generate({ "turns" => ["bad_string", nil, { "role" => "user", "content" => "hi" }] })
      result = adapter.parse(data)
      expect(result.first.turn_count).to eq(1)
    end

    it "uses provided source_id" do
      result = adapter.parse(generic_json, source_id: "conv-42")
      expect(result.first.source_id).to eq("conv-42")
    end

    it "raises IngestionError for nil input" do
      expect { adapter.parse(nil) }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for invalid JSON" do
      expect { adapter.parse("{broken") }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for JSON without turns or messages" do
      expect { adapter.parse('{"count": 5}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end

    it "raises IngestionError for JSON object with non-array turns" do
      expect { adapter.parse('{"turns": "bad"}') }
        .to raise_error(Wild::Telemetry::Pipeline::IngestionError)
    end
  end
end
