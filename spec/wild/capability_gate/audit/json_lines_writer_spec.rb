# frozen_string_literal: true

require "json"
require "tempfile"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- integration test needs registry + event chain
RSpec.describe Wild::CapabilityGate::Audit::JsonLinesWriter do
  let(:log_file) { Tempfile.new(["audit", ".jsonl"]) }
  let(:writer) { described_class.new(path: log_file.path) }
  let(:timestamp) { Time.utc(2026, 3, 17, 12, 0, 0) }

  let(:capability) do
    Wild::CapabilityGate::Capability.new(
      name: :basic_introspection, description: "Read-only inspection",
      risk_level: :standard
    )
  end

  let(:registry) { Wild::CapabilityGate::Registry.new([capability]) }

  let(:event) do
    result = Wild::CapabilityGate::EvaluationResult.allowed(
      capability_name: :basic_introspection,
      caller_id: "service-account:test-agent",
      timestamp: timestamp
    )
    Wild::CapabilityGate::Audit::Event.from_evaluation(
      result, registry: registry, session_id: "sess-001"
    )
  end

  after { log_file.close! }

  describe "#write" do
    it "writes a JSON object as a single line" do
      writer.write(event)

      lines = File.readlines(log_file.path)
      expect(lines.size).to eq(1)
      expect(lines.first).to end_with("\n")
    end

    it "writes valid JSON" do
      writer.write(event)

      line = File.read(log_file.path).strip
      parsed = JSON.parse(line)
      expect(parsed["event"]).to eq("capability_evaluation")
      expect(parsed["caller_id"]).to eq("service-account:test-agent")
    end

    it "appends multiple events on separate lines" do
      3.times { writer.write(event) }

      lines = File.readlines(log_file.path)
      expect(lines.size).to eq(3)
      lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
    end

    it "preserves existing content (append-only)" do
      File.write(log_file.path, "{\"existing\":true}\n")
      writer.write(event)

      lines = File.readlines(log_file.path)
      expect(lines.size).to eq(2)
      expect(JSON.parse(lines.first)["existing"]).to be true
      expect(JSON.parse(lines.last)["event"]).to eq("capability_evaluation")
    end

    it "returns nil" do
      expect(writer.write(event)).to be_nil
    end
  end

  describe "#path" do
    it "returns the configured path" do
      expect(writer.path).to eq(log_file.path)
    end
  end

  describe "immutability" do
    it "is frozen after creation" do
      expect(writer).to be_frozen
    end
  end

  describe "creates file if it does not exist" do
    it "creates the log file on first write" do
      new_path = "#{log_file.path}.new"
      new_writer = described_class.new(path: new_path)
      new_writer.write(event)

      expect(File.exist?(new_path)).to be true
      expect(JSON.parse(File.read(new_path).strip)["event"]).to eq("capability_evaluation")

      File.delete(new_path)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
