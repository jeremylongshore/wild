# frozen_string_literal: true

require "tmpdir"

RSpec.describe Wild::Analyzers::Permission::Loaders::GrantsLoader do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(tmpdir) }

  def write_grants(content)
    path = File.join(tmpdir, "grants.yml")
    File.write(path, content)
    path
  end

  describe ".load" do
    it "parses a valid grants.yml" do
      path = write_grants_yaml(default_grants_yaml_entries, tmpdir)
      grants = described_class.load(path)
      expect(grants.size).to eq(2)
    end

    it "returns Grant objects" do
      path = write_grants_yaml(default_grants_yaml_entries, tmpdir)
      grants = described_class.load(path)
      expect(grants).to all(be_a(Wild::Analyzers::Permission::Models::Grant))
    end

    it "parses caller_id correctly" do
      path = write_grants_yaml(default_grants_yaml_entries, tmpdir)
      grants = described_class.load(path)
      expect(grants.map(&:caller_id)).to include("ops-team", "dev-intern")
    end

    it "parses capabilities correctly" do
      path = write_grants_yaml(default_grants_yaml_entries, tmpdir)
      grants = described_class.load(path)
      ops = grants.find { |g| g.caller_id == "ops-team" }
      expect(ops.capabilities).to eq(["admin.jobs.*"])
    end

    it "parses expires_at correctly" do
      path = write_grants_yaml(default_grants_yaml_entries, tmpdir)
      grants = described_class.load(path)
      intern = grants.find { |g| g.caller_id == "dev-intern" }
      expect(intern.expires_at).to eq("2026-06-01")
    end

    it "skips entries with no caller_id" do
      entries = [{ "capabilities" => ["cap.one"] }, { "caller_id" => "valid", "capabilities" => ["cap.one"] }]
      path = write_grants_yaml(entries, tmpdir)
      grants = described_class.load(path)
      expect(grants.size).to eq(1)
    end

    it "skips entries with blank caller_id" do
      entries = [{ "caller_id" => "  ", "capabilities" => ["cap.one"] }]
      path = write_grants_yaml(entries, tmpdir)
      grants = described_class.load(path)
      expect(grants).to be_empty
    end

    it "skips entries where capabilities is not an array" do
      entries = [{ "caller_id" => "x", "capabilities" => "not-an-array" }]
      path = write_grants_yaml(entries, tmpdir)
      grants = described_class.load(path)
      expect(grants).to be_empty
    end

    it "raises LoadError when file does not exist" do
      expect do
        described_class.load("/nonexistent/grants.yml")
      end.to raise_error(Wild::Analyzers::Permission::LoadError, /not found/)
    end

    it "raises LoadError when top-level grants key is missing" do
      path = write_grants("tools: []")
      expect do
        described_class.load(path)
      end.to raise_error(Wild::Analyzers::Permission::LoadError, /grants/)
    end

    it "handles empty grants array" do
      path = write_grants_yaml([], tmpdir)
      grants = described_class.load(path)
      expect(grants).to be_empty
    end
  end
end
