# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Prerequisite do
  describe "#initialize" do
    it "creates a file_exists prerequisite" do
      prereq = described_class.new(type: "file_exists", path: "/tmp/attestation.md")

      expect(prereq.type).to eq(:file_exists)
      expect(prereq.params).to eq({ path: "/tmp/attestation.md" })
    end

    it "creates a config_value prerequisite" do
      prereq = described_class.new(type: :config_value, key: "admin_enabled", value: true)

      expect(prereq.type).to eq(:config_value)
      expect(prereq.params).to eq({ key: "admin_enabled", value: true })
    end

    it "freezes the object" do
      prereq = described_class.new(type: :file_exists, path: "/tmp/test")
      expect(prereq).to be_frozen
      expect(prereq.params).to be_frozen
    end

    it "rejects unknown prerequisite type" do
      expect { described_class.new(type: :magic_spell) }
        .to raise_error(ArgumentError, /unknown prerequisite type/)
    end
  end
end
