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
      expect(parsed["outcome"]).to eq("allow")
      expect(parsed["subject"]).to eq("service-account:test-agent")
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
      expect(JSON.parse(lines.last)["outcome"]).to eq("allow")
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

  # f-l08 addendum item 5: Audit::Event.coerce_context already bounds `context`
  # before an Event is even built (rejects NaN/Infinity, invalid encodings,
  # oversized payloads), so this exercises the writer's OWN defense-in-depth
  # for the case where #to_h returns unserializable data anyway (a double, or
  # a future field this coercion doesn't cover) — the decision must still get
  # written, not silently dropped because JSON.generate raised.
  describe "#write when the event hash is not JSON-serializable" do
    let(:nan_event) do
      instance_double(
        Wild::CapabilityGate::Audit::Event,
        to_h: {
          "timestamp" => "2026-03-17T12:00:00.000Z", "decision_id" => "d1",
          "capability" => "basic_introspection", "subject" => "svc:a",
          "outcome" => "allow", "policy_version" => "v1", "rationale" => "granted",
          "reason" => nil, "risk_level" => "standard",
          "prerequisites_checked" => [], "prerequisites_passed" => true,
          "extra" => { "session_id" => nil, "context" => { "value" => Float::NAN } }
        }
      )
    end

    let(:binary_event) do
      instance_double(
        Wild::CapabilityGate::Audit::Event,
        to_h: {
          "timestamp" => "2026-03-17T12:00:00.000Z", "decision_id" => "d2",
          "capability" => "basic_introspection", "subject" => "svc:a",
          "outcome" => "allow", "policy_version" => "v1", "rationale" => "granted",
          "reason" => nil, "risk_level" => "standard",
          "prerequisites_checked" => [], "prerequisites_passed" => true,
          "extra" => { "session_id" => nil, "context" => { "value" => "\xFF\xFE".dup.force_encoding("UTF-8") } }
        }
      )
    end

    it "still writes exactly one audit line for a NaN context instead of dropping the line" do
      expect(writer.write(nan_event)).to be_nil

      lines = File.readlines(log_file.path)
      expect(lines.size).to eq(1)
      parsed = JSON.parse(lines.first)
      expect(parsed["decision_id"]).to eq("d1")
      expect(parsed.dig("extra", "context")).to eq({ "dropped" => true, "reason" => "context not JSON-serializable" })
    end

    it "still writes exactly one audit line for invalid-encoding binary context" do
      expect(writer.write(binary_event)).to be_nil

      lines = File.readlines(log_file.path)
      expect(lines.size).to eq(1)
      parsed = JSON.parse(lines.first)
      expect(parsed["decision_id"]).to eq("d2")
      expect(parsed.dig("extra", "context")).to eq({ "dropped" => true, "reason" => "context not JSON-serializable" })
    end
  end

  describe "creates file if it does not exist" do
    it "creates the log file on first write" do
      new_path = "#{log_file.path}.new"
      new_writer = described_class.new(path: new_path)
      new_writer.write(event)

      expect(File.exist?(new_path)).to be true
      expect(JSON.parse(File.read(new_path).strip)["outcome"]).to eq("allow")

      File.delete(new_path)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
