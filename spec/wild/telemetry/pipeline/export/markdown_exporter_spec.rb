# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Export::MarkdownExporter do
  subject(:exporter) { described_class.new }

  let(:transcripts) { [make_transcript, make_transcript(source_id: "test-002")] }

  describe "#export" do
    it "returns a String" do
      expect(exporter.export(transcripts)).to be_a(String)
    end

    it "starts with a top-level heading" do
      expect(exporter.export(transcripts)).to start_with("# Transcript Export")
    end

    it "includes generated timestamp" do
      expect(exporter.export(transcripts)).to include("Generated")
    end

    it "includes transcript count" do
      expect(exporter.export(transcripts)).to include("Transcripts:** 2")
    end

    it "includes total turns" do
      output = exporter.export(transcripts)
      expect(output).to include("Total Turns")
    end

    it "includes a section for each transcript" do
      output = exporter.export(transcripts)
      expect(output).to include("test-001")
      expect(output).to include("test-002")
    end

    it "includes turns section" do
      output = exporter.export(transcripts)
      expect(output).to include("### Turns")
    end

    it 'labels user turns with "User"' do
      output = exporter.export(transcripts)
      expect(output).to include("**[0] User**")
    end

    it 'labels assistant turns with "Assistant"' do
      turns = [make_turn(role: :assistant, content: "Hi there")]
      t = make_transcript(turns: turns)
      output = exporter.export([t])
      expect(output).to include("**[0] Assistant**")
    end

    it "includes intents section when intents present" do
      t = make_transcript(intents: [make_intent(description: "Check connection")])
      output = exporter.export([t])
      expect(output).to include("### Detected Intents")
      expect(output).to include("Check connection")
    end

    it "includes tool references section when refs present" do
      t = make_transcript(tool_references: [make_tool_reference])
      output = exporter.export([t])
      expect(output).to include("### Tool References")
      expect(output).to include("inspect_connection")
    end

    it "shows no intents section when none present" do
      output = exporter.export(transcripts)
      expect(output).not_to include("### Detected Intents")
    end

    it "handles empty transcripts array" do
      output = exporter.export([])
      expect(output).to include("_No transcripts found._")
    end

    it "includes metadata when provided" do
      output = exporter.export(transcripts, metadata: { run_id: "abc" })
      expect(output).to include("run_id=abc")
    end

    it "shows _empty_ for turns with empty content" do
      turn = make_turn(content: "")
      t = make_transcript(turns: [turn])
      output = exporter.export([t])
      expect(output).to include("_empty_")
    end

    it "raises ExportError for non-Array input" do
      expect { exporter.export("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::ExportError)
    end
  end
end
