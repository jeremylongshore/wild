# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Prerequisites::ConfigValueChecker do
  def prereq(key:, value:)
    Wild::CapabilityGate::Prerequisite.new(type: :config_value, key: key, value: value)
  end

  describe ".check" do
    context "when context contains the expected value (string key)" do
      it "returns a passed result" do
        result = described_class.check(
          prereq(key: "admin_enabled", value: true),
          context: { "admin_enabled" => true }
        )

        expect(result).to be_satisfied
      end
    end

    context "when context contains the expected value (symbol key)" do
      it "returns a passed result" do
        result = described_class.check(
          prereq(key: "admin_enabled", value: true),
          context: { admin_enabled: true }
        )

        expect(result).to be_satisfied
      end
    end

    context "when context has wrong value" do
      it "returns a failed result with details" do
        result = described_class.check(
          prereq(key: "admin_enabled", value: true),
          context: { "admin_enabled" => false }
        )

        expect(result).not_to be_satisfied
        expect(result.details).to include("admin_enabled")
        expect(result.details).to include("true")
        expect(result.details).to include("false")
      end
    end

    context "when context is missing the key entirely" do
      it "returns a failed result" do
        result = described_class.check(
          prereq(key: "admin_enabled", value: true),
          context: {}
        )

        expect(result).not_to be_satisfied
        expect(result.details).to include("admin_enabled")
        expect(result.details).to include("nil")
      end
    end

    context "when key is nil" do
      it "returns a failed result" do
        bad_prereq = Wild::CapabilityGate::Prerequisite.new(type: :config_value, value: true)
        result = described_class.check(bad_prereq, context: {})

        expect(result).not_to be_satisfied
        expect(result.details).to include("missing required key parameter")
      end
    end

    context "with non-boolean expected values" do
      it "supports string comparison" do
        result = described_class.check(
          prereq(key: "env", value: "production"),
          context: { "env" => "production" }
        )

        expect(result).to be_satisfied
      end

      it "fails on type mismatch" do
        result = described_class.check(
          prereq(key: "count", value: 5),
          context: { "count" => "5" }
        )

        expect(result).not_to be_satisfied
      end
    end

    it "does not raise on errors (fail-closed)" do
      bad_prereq = instance_double(Wild::CapabilityGate::Prerequisite, type: :config_value, params: nil)
      result = described_class.check(bad_prereq, context: {})

      expect(result).not_to be_satisfied
      expect(result.details).to include("config_value check failed")
    end
  end
end
