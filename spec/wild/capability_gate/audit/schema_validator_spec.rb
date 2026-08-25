# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Audit::SchemaValidator do
  # A minimal conforming event hash (the 7 required fields + valid values).
  let(:conforming) do
    {
      "timestamp" => "2026-01-01T00:00:00.000Z",
      "decision_id" => "11111111-1111-1111-1111-111111111111",
      "capability" => "admin.jobs.view",
      "subject" => "agent:claude-code:abc",
      "outcome" => "deny",
      "policy_version" => "capabilities.yml@sha256:#{"a" * 64}",
      "rationale" => "denied:not_granted"
    }
  end

  describe ".validate!" do
    it "returns nil (does not raise) for a conforming event" do
      expect(described_class.validate!(conforming)).to be_nil
    end

    it "records a denied malformed/probing capability verbatim (no pattern constraint)" do
      # The security-critical case the strict pattern would have blocked: an
      # attacker probing with a garbage capability name must still be auditable.
      expect { described_class.validate!(conforming.merge("capability" => "12345")) }.not_to raise_error
      expect { described_class.validate!(conforming.merge("capability" => "")) }.not_to raise_error
    end

    it "raises AuditSchemaError for an out-of-enum outcome" do
      expect { described_class.validate!(conforming.merge("outcome" => "maybe")) }
        .to raise_error(Wild::CapabilityGate::AuditSchemaError, /outcome/)
    end

    it "raises AuditSchemaError when a required field is missing" do
      expect { described_class.validate!(conforming.except("decision_id")) }
        .to raise_error(Wild::CapabilityGate::AuditSchemaError, /required/)
    end

    it "raises AuditSchemaError for an additional top-level property (closed object)" do
      expect { described_class.validate!(conforming.merge("stray" => "x")) }
        .to raise_error(Wild::CapabilityGate::AuditSchemaError)
    end

    it "raises AuditSchemaError for a malformed policy_version" do
      expect { described_class.validate!(conforming.merge("policy_version" => "capabilities.yml@md5:short")) }
        .to raise_error(Wild::CapabilityGate::AuditSchemaError, /policy_version/)
    end
  end

  # f-l08-2: validation enabled (:auto default resolves to on in dev/test) but
  # `json_schemer` is a development-only gem (wild.gemspec) that a consuming
  # app may not have added. Prove the LoadError becomes a loud, greppable
  # Wild::ConfigurationError at first use rather than the LoadError itself
  # (which previously reached emit_audit's blanket StandardError rescue and,
  # with audit_logger nil by default, vanished with zero audit and zero log).
  describe ".validate! when json_schemer is not available" do
    after { described_class.reset! }

    it "raises Wild::ConfigurationError, not a bare LoadError" do
      described_class.reset!
      allow(described_class).to receive(:require).with("json_schemer").and_raise(LoadError)

      expect { described_class.validate!(conforming) }
        .to raise_error(Wild::ConfigurationError, /json_schemer/)
    end
  end

  describe ".valid?" do
    it "is true for a conforming event and false otherwise" do
      expect(described_class.valid?(conforming)).to be true
      expect(described_class.valid?(conforming.merge("outcome" => "maybe"))).to be false
    end
  end
end
