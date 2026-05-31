# frozen_string_literal: true

RSpec.describe Wild::Skillops::Discovery::SearchEngine do
  let(:registry) { populated_registry }
  let(:engine)   { registry.search_engine }

  describe "#search" do
    it "returns entries matching query by name" do
      results = engine.search("introspect")
      expect(results.map(&:name)).to include("introspect.schema")
    end

    it "returns entries matching query by tag" do
      results = engine.search("flush")
      expect(results.map(&:name)).to include("telemetry.flush")
    end

    it "returns entries matching query by description" do
      results = engine.search("gaps in")
      expect(results.map(&:name)).to include("gap.analyze")
    end

    it "returns results ordered by relevance" do
      # Name match scores higher than description match
      results = engine.search("admin")
      name_idx = results.index { |e| e.name == "admin.reindex" }
      expect(name_idx).not_to be_nil
    end

    it "is case-insensitive" do
      results = engine.search("SCHEMA")
      expect(results.map(&:name)).to include("introspect.schema")
    end

    it "returns empty array for nil query" do
      expect(engine.search(nil)).to eq([])
    end

    it "returns empty array for blank query" do
      expect(engine.search("  ")).to eq([])
    end

    it "returns empty array for no matches" do
      expect(engine.search("xyzzy-not-a-thing")).to eq([])
    end
  end

  describe "#search_in_category" do
    it "filters results to the specified category" do
      results = engine.search_in_category("admin", :admin)
      expect(results.all? { |e| e.skill.category == :admin }).to be true
    end

    it "returns empty array when no category matches" do
      expect(engine.search_in_category("admin", :governance)).to eq([])
    end
  end

  describe "#search_in_repo" do
    it "filters results to the specified repo" do
      results = engine.search_in_repo("introspect", "wild-rails-safe-introspection-mcp")
      expect(results.all? { |e| e.skill.repo == "wild-rails-safe-introspection-mcp" }).to be true
    end
  end
end
