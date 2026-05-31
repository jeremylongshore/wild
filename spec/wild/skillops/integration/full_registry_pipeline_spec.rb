# frozen_string_literal: true

# rubocop:disable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/MultipleExpectations, RSpec/ExampleLength

require "json"

RSpec.describe "Full registry pipeline" do
  let(:registry) { Wild::Skillops.build }

  it "registers, updates, tracks health, assigns ownership, and exports" do
    # Register
    skill = make_skill(name: "pipeline.test", description: "Pipeline test skill",
                       tags: %w[pipeline test], category: :workflow)
    entry = registry.registrar.register(skill)
    expect(entry).to be_a(Wild::Skillops::Models::RegistryEntry)

    # Update
    registry.registrar.update("pipeline.test", description: "Updated description", version: "1.1.0")
    found = registry.finder.find_by_name("pipeline.test")
    expect(found.skill.description).to eq("Updated description")

    # Track health
    registry.health_tracker.record("pipeline.test", state: :available, message: "All good")
    expect(registry.health_tracker.status_for("pipeline.test").state).to eq(:available)

    # Assign owner
    registry.ownership_resolver.assign("pipeline.test", team: "platform", contact: "eng@example.com")
    expect(registry.ownership_resolver.owner_for("pipeline.test").team).to eq("platform")

    # Search
    results = registry.search_engine.search("pipeline")
    expect(results.map(&:name)).to include("pipeline.test")

    # Export JSON
    json = registry.json_exporter.export_json
    parsed = JSON.parse(json)
    expect(parsed["skill_count"]).to eq(1)

    # Export Markdown
    md = registry.markdown_exporter.export
    expect(md).to include("pipeline.test")
    expect(md).to include("All good")
  end

  it "enforces lifecycle transitions across the full flow" do
    registry.registrar.register(make_skill(name: "lifecycle.full", lifecycle_state: :draft))
    registry.registrar.update("lifecycle.full", lifecycle_state: :active)
    registry.registrar.deprecate("lifecycle.full", reason: "Replaced by v2")
    registry.registrar.retire("lifecycle.full")

    entry = registry.finder.find_by_name("lifecycle.full")
    expect(entry.lifecycle_state).to eq(:retired)
  end

  it "manages version history through updates" do
    registry.registrar.register(make_skill(name: "versioned.skill", version: "1.0.0"))
    registry.registrar.update("versioned.skill", version: "1.1.0", description: "v1.1 desc")
    registry.registrar.update("versioned.skill", version: "1.2.0", description: "v1.2 desc")

    versions = registry.version_manager.versions_for("versioned.skill")
    expect(versions.size).to eq(3)

    changelog = registry.changelog_builder.build_text("versioned.skill")
    expect(changelog).to include("1.2.0")
    expect(changelog).to include("1.0.0")
  end

  it "aggregates health across multiple skills" do
    %w[s1 s2 s3].each_with_index do |name, i|
      registry.registrar.register(make_skill(name: name, description: "Skill #{i}"))
    end
    registry.health_tracker.record("s1", state: :available)
    registry.health_tracker.record("s2", state: :degraded)

    summary = registry.health_aggregator.summary
    expect(summary[:total_skills]).to eq(3)
    expect(summary[:tracked]).to eq(2)
    expect(summary[:untracked]).to eq(1)
    expect(summary[:counts][:available]).to eq(1)
    expect(summary[:counts][:degraded]).to eq(1)
  end

  it "supports tag-based discovery across multiple skills" do
    registry.registrar.register(make_skill(name: "tag.a", tags: %w[common specific-a]))
    registry.registrar.register(make_skill(name: "tag.b", tags: %w[common specific-b],
                                           description: "Tag B skill"))
    registry.registrar.register(make_skill(name: "tag.c", tags: ["other"], description: "Tag C skill"))

    common_results = registry.finder.find_by_tag("common")
    expect(common_results.map(&:name)).to match_array(%w[tag.a tag.b])

    specific = registry.finder.find_by_tag("specific-a")
    expect(specific.map(&:name)).to eq(["tag.a"])
  end
end

# rubocop:enable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/MultipleExpectations, RSpec/ExampleLength
