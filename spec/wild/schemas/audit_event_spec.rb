# frozen_string_literal: true

require "yaml"

# Schema tests describe a data file, not a class — RSpec/DescribeClass +
# RSpec/ExpectActual fire on literal-string actuals in pattern checks below.
# rubocop:disable RSpec/DescribeClass, RSpec/ExpectActual
RSpec.describe "lib/wild/schemas/capability_gate/audit_event.yml" do
  subject(:schema) { YAML.safe_load_file(schema_path, permitted_classes: []) }

  let(:schema_path) do
    File.expand_path(
      "../../../lib/wild/schemas/capability_gate/audit_event.yml",
      __dir__
    )
  end

  describe "structure" do
    it "loads as a JSON Schema document" do
      expect(schema).to be_a(Hash)
      expect(schema.fetch("$schema")).to start_with("https://json-schema.org/draft/")
      expect(schema.fetch("type")).to eq("object")
    end

    it "declares the seven required decision-core fields (audit_emit_ms removed, wild-rvv.4.1.3)" do
      expect(schema.fetch("required")).to contain_exactly(
        "timestamp",
        "decision_id",
        "capability",
        "subject",
        "outcome",
        "policy_version",
        "rationale"
      )
    end

    it "is a closed object — additionalProperties: false" do
      expect(schema.fetch("additionalProperties")).to be(false)
    end

    it "does NOT carry audit_emit_ms (emit timing is telemetry, not an audit value)" do
      expect(schema.fetch("required")).not_to include("audit_emit_ms")
      expect(schema.fetch("properties")).not_to have_key("audit_emit_ms")
    end

    # Promoted first-class fields (Armstrong + Hickey): the gate's own
    # explanation of its decision must be schema-validated, not buried in extra.
    it "promotes reason + risk_level + prerequisites_* to first-class properties" do
      props = schema.fetch("properties")
      expect(props).to include("reason", "risk_level", "prerequisites_checked", "prerequisites_passed")
    end

    it "keeps `extra` as the consumer-open extension surface only" do
      expect(schema.fetch("properties").fetch("extra").fetch("type")).to eq("object")
    end
  end

  describe "capability pattern" do
    # Real capability names are dotted (admin.jobs.view) or flat
    # (basic_introspection); the pattern must accept both (wild-rvv.4.1.3).
    it "accepts dotted and flat lowercase identifiers, rejects uppercase/leading-digit" do
      pattern = Regexp.new(schema.fetch("properties").fetch("capability").fetch("pattern"))
      expect("admin.jobs.view").to match(pattern)
      expect("basic_introspection").to match(pattern)
      expect("Admin.Jobs").not_to match(pattern)
      expect("9lives").not_to match(pattern)
    end
  end

  describe "outcome enum" do
    # F2 mandate: outcome is one of :allow, :deny, :evaluation_error. No
    # fourth outcome can sneak in via schema drift.
    it "is exactly [allow, deny, evaluation_error]" do
      outcome = schema.fetch("properties").fetch("outcome")
      expect(outcome.fetch("enum")).to contain_exactly("allow", "deny", "evaluation_error")
    end
  end

  describe "policy_version pattern" do
    # SHA-256 fingerprint enables audit replay against a known policy state.
    it "matches capabilities.yml@sha256:<64-hex>" do
      pattern = schema.fetch("properties").fetch("policy_version").fetch("pattern")
      expect("capabilities.yml@sha256:#{"a" * 64}").to match(Regexp.new(pattern))
      expect("capabilities.yml@sha256:short").not_to match(Regexp.new(pattern))
      expect("capabilities.yml@md5:abc").not_to match(Regexp.new(pattern))
    end
  end

  describe "extension surface" do
    it "allows an optional `extra` object for consumer-defined context" do
      extra = schema.fetch("properties").fetch("extra")
      expect(extra.fetch("type")).to eq("object")
    end
  end

  # Hickey's most-costly finding (wild-rvv.4.1.3): two hand-maintained shapes
  # with no derivation relationship WILL re-drift. This is the gate that makes
  # drift impossible to merge green — real Event#to_h output is validated
  # against this very schema. (Structural validation here; the json-schema gem
  # validator wired at emit time is wild-rvv.4.1.2, which upgrades this to full
  # draft-2020-12 validation.)
  describe "round-trip conformance: Event#to_h conforms to this schema" do
    let(:sample_events) do
      base = {
        timestamp: Time.utc(2026, 1, 1, 12, 0, 0),
        subject: "agent:claude-code:abc123",
        capability: "admin.jobs.view",
        risk_level: "high",
        policy_version: "capabilities.yml@sha256:#{"a" * 64}"
      }
      [
        Wild::CapabilityGate::Audit::Event.new(**base, outcome: "allow"),
        Wild::CapabilityGate::Audit::Event.new(**base, outcome: "deny", reason: "not_granted"),
        Wild::CapabilityGate::Audit::Event.new(**base, outcome: "evaluation_error", reason: "evaluation_error")
      ]
    end

    it "emits every required field and NO field outside the schema (additionalProperties:false)" do
      props = schema.fetch("properties").keys
      required = schema.fetch("required")
      sample_events.each do |event|
        keys = event.to_h.keys
        expect(required - keys).to eq([]), "#{event.outcome}: missing required #{required - keys}"
        expect(keys - props).to eq([]), "#{event.outcome}: keys not in schema #{keys - props}"
      end
    end

    it "emits values conforming to the schema's enum + patterns + minLength" do
      enum = schema.dig("properties", "outcome", "enum")
      cap_re = Regexp.new(schema.dig("properties", "capability", "pattern"))
      pv_re = Regexp.new(schema.dig("properties", "policy_version", "pattern"))
      sample_events.each do |event|
        h = event.to_h
        expect(enum).to include(h["outcome"])
        expect(h["capability"]).to match(cap_re)
        expect(h["policy_version"]).to match(pv_re)
        expect(h["rationale"]).not_to be_empty
        expect(h["decision_id"]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/ExpectActual
