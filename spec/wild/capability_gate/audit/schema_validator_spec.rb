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
  # error at first use rather than the LoadError itself (which previously
  # reached emit_audit's blanket StandardError rescue and, with audit_logger
  # nil by default, vanished with zero audit and zero log). f-l08 addendum
  # item 12: the class is AuditValidatorUnavailableError (a subclass of
  # AuditSchemaError), NOT the gem-wide Wild::ConfigurationError — kept out of
  # that hierarchy on purpose so CapabilityGate's DEVELOPER_ERRORS whitelist
  # can re-raise every developer-bug signal from THIS namespace with a single
  # AuditSchemaError check, without also giving a free pass to an unrelated
  # ConfigurationError a future prerequisite checker might raise. The message
  # still reads like a configuration problem even though the class is not.
  describe ".validate! when json_schemer is not available" do
    after { described_class.reset! }

    it "raises AuditValidatorUnavailableError (an AuditSchemaError), not a bare LoadError or ConfigurationError" do
      described_class.reset!
      allow(described_class).to receive(:require).with("json_schemer").and_raise(LoadError)

      expect { described_class.validate!(conforming) }
        .to raise_error(Wild::CapabilityGate::AuditValidatorUnavailableError, /json_schemer/)
    end

    it "is-a AuditSchemaError (covered by CapabilityGate::DEVELOPER_ERRORS with one class check)" do
      described_class.reset!
      allow(described_class).to receive(:require).with("json_schemer").and_raise(LoadError)

      expect { described_class.validate!(conforming) }.to raise_error(Wild::CapabilityGate::AuditSchemaError)
    end

    it "is NOT a Wild::ConfigurationError (deliberately not multiply-inherited)" do
      described_class.reset!
      allow(described_class).to receive(:require).with("json_schemer").and_raise(LoadError)

      begin
        described_class.validate!(conforming)
      rescue Wild::CapabilityGate::AuditValidatorUnavailableError => e
        expect(e).not_to be_a(Wild::ConfigurationError)
      end
    end

    it "exercises the Gate#initialize boot-time probe path directly (ensure_available!)" do
      described_class.reset!
      allow(described_class).to receive(:require).with("json_schemer").and_raise(LoadError)

      expect { described_class.ensure_available! }
        .to raise_error(Wild::CapabilityGate::AuditValidatorUnavailableError, /json_schemer/)
    end
  end

  describe ".valid?" do
    it "is true for a conforming event and false otherwise" do
      expect(described_class.valid?(conforming)).to be true
      expect(described_class.valid?(conforming.merge("outcome" => "maybe"))).to be false
    end
  end

  # f-l08 addendum item 2: nothing in this gem sets Wild.config.environment
  # from Rails.env, so a real Rails app that never touches
  # Wild.config.environment would silently stay on its :development default
  # even in production — and json_schemer is a DEVELOPMENT-only gem, so a
  # production app without it would have raised on EVERY evaluation. .enabled?
  # now consults the real Rails.env first (production forces validation off)
  # before falling back to the pre-existing Wild.config.environment check.
  describe ".enabled? in a real Rails production environment" do
    # Wild.reset_config! runs before every example (spec_helper.rb), so no
    # manual save/restore of Wild.config.environment is needed here.
    before { Wild.configure { |c| c.capability_gate.validate_audit_events = :auto } }

    it "is off when Rails.env is production, even though Wild.config.environment was never updated" do
      # The exact bug this closes: Wild.config.environment stays at its
      # :development default (nothing wires it from Rails.env), which alone
      # would make .enabled? return true here.
      Wild.configure { |c| c.environment = :development }
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(described_class.enabled?).to be false
    end

    it "falls back to Wild.config.environment when Rails.env is not production" do
      Wild.configure { |c| c.environment = :test }
      allow(Rails.env).to receive(:production?).and_return(false)

      expect(described_class.enabled?).to be true
    end

    it "does not raise if Rails.env itself misbehaves (defensive fallback)" do
      allow(Rails).to receive(:env).and_raise("Rails.env exploded")
      Wild.configure { |c| c.environment = :test }

      expect(described_class.enabled?).to be true
    end
  end
end
