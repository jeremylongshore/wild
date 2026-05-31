# frozen_string_literal: true

# rubocop:disable Rails/DynamicFindBy

RSpec.describe Wild::Skillops::Registry::Finder do
  let(:registry) { populated_registry }
  let(:finder) { registry.finder }

  describe "#find_by_name" do
    it "returns the entry for a registered skill" do
      entry = finder.find_by_name("introspect.schema")
      expect(entry.name).to eq("introspect.schema")
    end

    it "raises NotFoundError for unknown name" do
      expect { finder.find_by_name("no.such") }.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#find_by_name_or_nil" do
    it "returns nil for unknown name" do
      expect(finder.find_by_name_or_nil("no.such")).to be_nil
    end
  end

  describe "#find_by_tag" do
    it "returns entries matching the tag" do
      entries = finder.find_by_tag("admin")
      expect(entries.map(&:name)).to include("admin.reindex")
    end

    it "returns empty array for unknown tag" do
      expect(finder.find_by_tag("zzz-not-real")).to eq([])
    end
  end

  describe "#find_by_repo" do
    it "returns all skills from a given repo" do
      entries = finder.find_by_repo("wild-admin-tools-mcp")
      expect(entries.all? { |e| e.skill.repo == "wild-admin-tools-mcp" }).to be true
    end

    it "returns empty array for unknown repo" do
      expect(finder.find_by_repo("no-such-repo")).to eq([])
    end
  end

  describe "#find_by_category" do
    it "returns skills of the specified category" do
      entries = finder.find_by_category(:telemetry)
      expect(entries.map(&:name)).to include("telemetry.flush")
    end

    it "returns empty for an unused category" do
      expect(finder.find_by_category(:governance)).to eq([])
    end
  end

  describe "#find_by_lifecycle" do
    it "returns skills with the given lifecycle state" do
      entries = finder.find_by_lifecycle(:draft)
      expect(entries).not_to be_empty
    end
  end

  describe "#search" do
    it "finds by partial name match" do
      results = finder.search("schema")
      expect(results.map(&:name)).to include("introspect.schema")
    end

    it "finds by partial description match" do
      results = finder.search("Reindex")
      expect(results.map(&:name)).to include("admin.reindex")
    end

    it "finds by tag match" do
      results = finder.search("transcript")
      expect(results.map(&:name)).to include("gap.analyze")
    end

    it "returns empty array for nil query" do
      expect(finder.search(nil)).to eq([])
    end

    it "returns empty array for blank query" do
      expect(finder.search("   ")).to eq([])
    end
  end

  describe "#all" do
    it "returns all registered entries" do
      expect(finder.all.size).to eq(4)
    end
  end
end

# rubocop:enable Rails/DynamicFindBy
