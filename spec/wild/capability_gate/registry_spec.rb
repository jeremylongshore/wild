# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Registry do
  let(:fixtures_dir) { File.expand_path("../../fixtures", __dir__) }

  describe ".from_file" do
    context "with valid configuration" do
      subject(:registry) { described_class.from_file(File.join(fixtures_dir, "valid_capabilities.yml")) }

      it "loads all capabilities" do
        expect(registry.size).to eq(3)
      end

      it "provides lookup by name" do
        cap = registry.find(:basic_introspection)
        expect(cap).not_to be_nil
        expect(cap.name).to eq(:basic_introspection)
        expect(cap.risk_level).to eq(:standard)
      end

      it "loads elevated capabilities with prerequisites" do
        cap = registry.find(:privileged_introspection)
        expect(cap.risk_level).to eq(:elevated)
        expect(cap).to be_prerequisites
        expect(cap.prerequisites.first.type).to eq(:file_exists)
      end

      it "loads critical capabilities with multiple prerequisites" do
        cap = registry.find(:admin_tools)
        expect(cap.risk_level).to eq(:critical)
        expect(cap.prerequisites.size).to eq(2)
      end

      it "lists all capability names" do
        expect(registry.names).to contain_exactly(:basic_introspection, :privileged_introspection, :admin_tools)
      end

      it "returns all capabilities" do
        expect(registry.all.map(&:name)).to contain_exactly(:basic_introspection, :privileged_introspection,
                                                            :admin_tools)
      end
    end

    context "with empty capabilities list" do
      it "loads an empty registry" do
        registry = described_class.from_file(File.join(fixtures_dir, "empty_capabilities.yml"))
        expect(registry.size).to eq(0)
        expect(registry.all).to eq([])
      end
    end

    context "with invalid configuration" do
      it "raises on missing file" do
        expect { described_class.from_file("/nonexistent/path.yml") }
          .to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError, /file not found/)
      end

      it "raises on malformed YAML" do
        expect { described_class.from_file(File.join(fixtures_dir, "invalid_yaml.yml")) }
          .to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError, /YAML syntax error/)
      end

      it "raises on missing top-level capabilities key" do
        expect { described_class.from_file(File.join(fixtures_dir, "missing_top_key.yml")) }
          .to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError, /missing top-level/)
      end

      it "raises on missing capability name" do
        expect { described_class.from_file(File.join(fixtures_dir, "invalid_missing_name.yml")) }
          .to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError, /missing 'name'/)
      end

      it "raises on unknown risk level" do
        expect { described_class.from_file(File.join(fixtures_dir, "invalid_risk_level.yml")) }
          .to raise_error(Wild::CapabilityGate::Registry::ConfigLoader::ConfigError, /unknown risk_level/)
      end

      it "raises on duplicate capability names" do
        expect { described_class.from_file(File.join(fixtures_dir, "duplicate_names.yml")) }
          .to raise_error(Wild::CapabilityGate::Registry::DuplicateCapabilityError, /duplicate capability name/)
      end
    end
  end

  describe "#find" do
    let(:registry) { described_class.from_file(File.join(fixtures_dir, "valid_capabilities.yml")) }

    it "returns the capability for a known name" do
      expect(registry.find(:basic_introspection)).to be_a(Wild::CapabilityGate::Capability)
    end

    it "accepts string names" do
      expect(registry.find("basic_introspection")).to be_a(Wild::CapabilityGate::Capability)
    end

    it "returns nil for unknown names" do
      expect(registry.find(:nonexistent)).to be_nil
    end
  end

  describe "#fetch" do
    let(:registry) { described_class.from_file(File.join(fixtures_dir, "valid_capabilities.yml")) }

    it "returns the capability for a known name" do
      expect(registry.fetch(:basic_introspection).name).to eq(:basic_introspection)
    end

    it "raises KeyError for unknown names" do
      expect { registry.fetch(:nonexistent) }
        .to raise_error(KeyError, /unknown capability/)
    end
  end

  describe "#known?" do
    let(:registry) { described_class.from_file(File.join(fixtures_dir, "valid_capabilities.yml")) }

    it "returns true for registered capabilities" do
      expect(registry).to be_known(:basic_introspection)
    end

    it "returns false for unregistered capabilities" do
      expect(registry).not_to be_known(:nonexistent)
    end
  end

  describe "immutability" do
    it "freezes the registry after construction" do
      registry = described_class.from_file(File.join(fixtures_dir, "valid_capabilities.yml"))
      expect(registry).to be_frozen
    end
  end
end
