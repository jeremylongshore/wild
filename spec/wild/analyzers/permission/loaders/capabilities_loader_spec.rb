# frozen_string_literal: true

require "tmpdir"

RSpec.describe Wild::Analyzers::Permission::Loaders::CapabilitiesLoader do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  def write_caps(content)
    path = File.join(tmpdir, "capabilities.yml")
    File.write(path, content)
    path
  end

  describe ".load" do
    it "parses a valid capabilities.yml" do
      path = write_capabilities_yaml(default_capabilities_yaml_entries, tmpdir)
      caps = described_class.load(path)
      expect(caps.size).to eq(4)
      expect(caps.map(&:name)).to include("admin.jobs.view", "admin.jobs.retry")
    end

    it "returns Capability objects" do
      path = write_capabilities_yaml(default_capabilities_yaml_entries, tmpdir)
      caps = described_class.load(path)
      expect(caps).to all(be_a(Wild::Analyzers::Permission::Models::Capability))
    end

    it "sets risk_level correctly" do
      path = write_capabilities_yaml(default_capabilities_yaml_entries, tmpdir)
      caps = described_class.load(path)
      retry_cap = caps.find { |c| c.name == "admin.jobs.retry" }
      expect(retry_cap.risk_level).to eq("medium")
    end

    it "sets prerequisites correctly" do
      path = write_capabilities_yaml(default_capabilities_yaml_entries, tmpdir)
      caps = described_class.load(path)
      retry_cap = caps.find { |c| c.name == "admin.jobs.retry" }
      expect(retry_cap.prerequisites).to eq(["admin.jobs.view"])
    end

    it "defaults risk_level to low when missing" do
      entries = [{ "name" => "some.cap" }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = described_class.load(path)
      expect(caps.first.risk_level).to eq("low")
    end

    it "skips entries with no name" do
      entries = [{ "description" => "no name here" }, { "name" => "valid.cap" }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = described_class.load(path)
      expect(caps.size).to eq(1)
      expect(caps.first.name).to eq("valid.cap")
    end

    it "skips entries with blank name" do
      entries = [{ "name" => "   " }, { "name" => "valid.cap" }]
      path = write_capabilities_yaml(entries, tmpdir)
      caps = described_class.load(path)
      expect(caps.map(&:name)).to eq(["valid.cap"])
    end

    it "raises LoadError when file does not exist" do
      expect do
        described_class.load("/nonexistent/capabilities.yml")
      end.to raise_error(Wild::Analyzers::Permission::LoadError, /not found/)
    end

    it "raises LoadError when YAML is invalid" do
      path = write_caps("capabilities: [bad: yaml: here:\n  - oops")
      expect do
        described_class.load(path)
      end.to raise_error(Wild::Analyzers::Permission::LoadError)
    end

    it "raises LoadError when top-level key is missing" do
      path = write_caps("tools:\n  - name: foo")
      expect do
        described_class.load(path)
      end.to raise_error(Wild::Analyzers::Permission::LoadError, /capabilities/)
    end

    it "handles empty capabilities array" do
      path = write_capabilities_yaml([], tmpdir)
      caps = described_class.load(path)
      expect(caps).to be_empty
    end
  end
end
