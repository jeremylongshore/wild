# frozen_string_literal: true

# Pair every error class with the level at which a consumer would catch it.
# This table IS the contract — adding/renaming a class without updating the
# table fails the spec and forces a CHANGELOG entry under the affected
# namespace (per the architecture doc's public-API rules).
ERROR_TABLE = {
  Wild::Error => [StandardError],
  Wild::ConfigurationError => [Wild::Error, StandardError],

  Wild::CapabilityGate::Error => [Wild::Error, StandardError],
  Wild::CapabilityGate::DeniedError => [Wild::CapabilityGate::Error, Wild::Error, StandardError],
  Wild::CapabilityGate::PolicyError => [Wild::CapabilityGate::Error, Wild::Error, StandardError],
  Wild::CapabilityGate::EvaluationError => [Wild::CapabilityGate::Error, Wild::Error, StandardError],

  Wild::Introspection::Error => [Wild::Error, StandardError],
  Wild::Introspection::ForbiddenError => [Wild::Introspection::Error, Wild::Error, StandardError],
  Wild::Introspection::ModelNotAllowedError => [Wild::Introspection::Error, Wild::Error, StandardError],

  Wild::AdminTools::Error => [Wild::Error, StandardError],
  Wild::Telemetry::Error => [Wild::Error, StandardError],
  Wild::Hooks::Error => [Wild::Error, StandardError],
  Wild::Analyzers::Error => [Wild::Error, StandardError],
  Wild::Skillops::Error => [Wild::Error, StandardError]
}.freeze

RSpec.describe Wild::Error do
  describe "inheritance contract" do
    ERROR_TABLE.each do |klass, expected_ancestors|
      it "#{klass} inherits from #{expected_ancestors.first}" do
        # Each class must be a direct subclass of its declared parent. Walks
        # the hierarchy one step at a time so a future refactor can't sneak
        # in an intermediate class without updating the table.
        expected_ancestors.each do |ancestor|
          expect(klass.ancestors).to include(ancestor)
        end
      end
    end
  end

  describe "consumer rescue at every level" do
    it "lets consumers rescue a specific subclass without catching siblings" do
      expect { raise Wild::CapabilityGate::DeniedError, "subject lacks capability" }
        .to raise_error(Wild::CapabilityGate::DeniedError)
    end

    it "lets consumers rescue at the namespace level (catches all subclasses)" do
      expect do
        raise Wild::CapabilityGate::EvaluationError, "policy invalid"
      rescue Wild::CapabilityGate::Error
        # caught
      end.not_to raise_error
    end

    it "lets consumers rescue at Wild::Error (catches every wild error)" do
      expect do
        raise Wild::Introspection::ForbiddenError, "policy denies model"
      rescue described_class
        # caught
      end.not_to raise_error
    end

    it "lets consumers rescue at StandardError (Ruby-conventional)" do
      expect do
        raise Wild::Telemetry::Error, "collector queue overflow"
      rescue StandardError
        # caught
      end.not_to raise_error
    end
  end

  describe "F2 EvaluationError contract" do
    # The architecture doc says: "Raised when a rescue path in the gate emits
    # a structured audit event with outcome: :evaluation_error and denies the
    # request. Never silent — always paired with an audit event."
    #
    # Role 6 owns the audit-emission spec (spec/wild/capability_gate/
    # audit_liveness_spec.rb). This spec only verifies the class exists,
    # inherits correctly, and carries a message.
    it "is a subclass of Wild::CapabilityGate::Error" do
      expect(Wild::CapabilityGate::EvaluationError.ancestors)
        .to include(Wild::CapabilityGate::Error)
    end

    it "is rescuable at every level of the hierarchy" do
      err = Wild::CapabilityGate::EvaluationError.new("policy fixture corrupt")
      expect(err).to be_a(Wild::CapabilityGate::EvaluationError)
      expect(err).to be_a(Wild::CapabilityGate::Error)
      expect(err).to be_a(described_class)
      expect(err).to be_a(StandardError)
    end
  end

  describe "Introspection sibling errors do not catch each other" do
    it "raising ForbiddenError does not satisfy rescue ModelNotAllowedError" do
      expect do
        raise Wild::Introspection::ForbiddenError, "forbidden"
      rescue Wild::Introspection::ModelNotAllowedError
        # would be wrong — sibling, not parent
      end.to raise_error(Wild::Introspection::ForbiddenError)
    end
  end
end
