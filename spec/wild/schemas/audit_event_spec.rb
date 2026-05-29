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

    it "declares all eight required fields from 003-AT-ARCH § Audit trail" do
      expect(schema.fetch("required")).to contain_exactly(
        "timestamp",
        "decision_id",
        "capability",
        "subject",
        "outcome",
        "policy_version",
        "rationale",
        "audit_emit_ms"
      )
    end

    it "is a closed object — additionalProperties: false" do
      expect(schema.fetch("additionalProperties")).to be(false)
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

  describe "audit_emit_ms numeric floor" do
    # F2 audit-liveness spec uses this to detect emitters that silently fail
    # (real emit takes >0 ms; mocked emit returns 0 → fails).
    it "rejects negative values" do
      audit_emit_ms = schema.fetch("properties").fetch("audit_emit_ms")
      expect(audit_emit_ms.fetch("type")).to eq("number")
      expect(audit_emit_ms.fetch("minimum")).to eq(0)
    end
  end

  describe "extension surface" do
    it "allows an optional `extra` object for consumer-defined context" do
      extra = schema.fetch("properties").fetch("extra")
      expect(extra.fetch("type")).to eq("object")
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/ExpectActual
