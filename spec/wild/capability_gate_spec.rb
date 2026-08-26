# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate do
  # F1 collapsed nine per-namespace VERSION constants into one Wild::VERSION
  # at the gem level. The namespace inherits its version from the gem.
  it "inherits its version from the gem-level Wild::VERSION" do
    expect(Wild::VERSION).not_to be_nil
    expect(Wild::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  # Real coverage of Gate/Evaluator/Registry lives under spec/wild/capability_gate/**.
  # This top-level spec's job (review wave finding f-x2-7: previously two vanity
  # examples, VERSION format + "is a Module") is to smoke-test the namespace's
  # public entry point end to end: Wild::CapabilityGate.new is documented as a
  # Gate.new convenience constructor, and a Gate built from a config directory
  # with no grants must fail closed, not raise, on evaluation.
  describe ".new" do
    it "delegates to Gate and fails closed (denies, does not raise) for an unknown caller" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "capabilities.yml"), { "capabilities" => [] }.to_yaml)
        File.write(File.join(dir, "grants.yml"), { "grants" => [] }.to_yaml)

        gate = described_class.new(config_path: dir)
        result = gate.evaluate(caller: "service-account:unknown", capability: :basic_introspection)

        expect(gate).to be_a(Wild::CapabilityGate::Gate)
        expect(result).not_to be_allowed
      end
    end
  end
end
