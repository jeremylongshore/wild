# frozen_string_literal: true

# rubocop:disable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/MultipleExpectations

RSpec.describe "Edge cases" do
  let(:registry) { Wild::Skillops.build }

  describe "Capacity limits" do
    it "allows exactly max_skills registrations" do
      Wild.configure { |c| c.skillops.max_skills = 3 }
      make_skill_set(count: 3).each { |s| registry.registrar.register(s) }
      expect(registry.store.size).to eq(3)
    end

    it "raises RegistryCapacityError on the one-over-limit registration" do
      Wild.configure { |c| c.skillops.max_skills = 2 }
      make_skill_set(count: 2).each { |s| registry.registrar.register(s) }
      extra = make_skill(name: "overflow.skill", description: "Extra skill")
      expect do
        registry.registrar.register(extra)
      end.to raise_error(Wild::Skillops::RegistryCapacityError)
    end

    it "does not count updates against capacity" do
      Wild.configure { |c| c.skillops.max_skills = 1 }
      registry.registrar.register(make_skill(name: "only.one"))
      expect do
        20.times { |i| registry.registrar.update("only.one", version: "1.0.#{i}") }
      end.not_to raise_error
    end
  end

  describe "Version limits" do
    it "raises VersionCapacityError when max_versions_per_skill is reached" do
      Wild.configure { |c| c.skillops.max_versions_per_skill = 3 }
      registry.registrar.register(make_skill(name: "ver.limit", version: "1.0.0"))
      registry.version_manager.record_version("ver.limit", "1.1.0")
      registry.version_manager.record_version("ver.limit", "1.2.0")
      expect do
        registry.version_manager.record_version("ver.limit", "1.3.0")
      end.to raise_error(Wild::Skillops::VersionCapacityError)
    end
  end

  # Configuration freeze/frozen? machinery was removed in the Role 5 PR-5
  # move per Wild's "no-freeze configuration" design (see lib/wild/configuration.rb
  # § "Mutation is expected during Wild.configure { ... } and read-only thereafter").
  # The old gem's per-namespace ConfigurationFrozenError is subsumed by
  # Wild::ConfigurationError; the 2 freeze-roundtrip specs that lived here are
  # deleted rather than rewritten to avoid testing absent behavior (F3 — no
  # vanity tests).

  describe "Lifecycle terminal state" do
    it "cannot transition out of retired state" do
      lm = Wild::Skillops::Governance::LifecycleManager.new
      %i[active draft deprecated retired].each do |target|
        expect do
          lm.transition!(:retired, target)
        end.to raise_error(Wild::Skillops::LifecycleError)
      end
    end
  end

  describe "Empty registry operations" do
    it "returns empty array for all queries on empty registry" do
      expect(registry.finder.all).to eq([])
      expect(registry.finder.search("anything")).to eq([])
      expect(registry.finder.find_by_tag("tag")).to eq([])
      expect(registry.finder.find_by_repo("repo")).to eq([])
      expect(registry.finder.find_by_category(:admin)).to eq([])
      expect(registry.finder.find_by_lifecycle(:draft)).to eq([])
    end

    it "returns empty summary for empty registry" do
      summary = registry.health_aggregator.summary
      expect(summary[:total_skills]).to eq(0)
      expect(summary[:tracked]).to eq(0)
    end
  end

  describe "Skills with no tags" do
    it "registers and can be found by name with no tags" do
      skill = make_skill(name: "no.tags", tags: [])
      registry.registrar.register(skill)
      found = registry.finder.find_by_name("no.tags")
      expect(found.skill.tags).to eq([])
    end
  end

  describe "Skills with many capabilities_required" do
    it "stores and retrieves capabilities_required" do
      caps = %w[cap:read cap:write cap:admin cap:delete]
      skill = make_skill(name: "many.caps", capabilities_required: caps)
      registry.registrar.register(skill)
      found = registry.finder.find_by_name("many.caps")
      expect(found.skill.capabilities_required).to eq(caps)
    end
  end

  describe "Markdown export with all optional fields populated" do
    it "renders a complete entry without errors" do
      skill = make_skill(name: "full.entry", tags: %w[a b])
      registry.registrar.register(skill)
      registry.health_tracker.record("full.entry", state: :degraded, message: "service slow")
      registry.ownership_resolver.assign("full.entry", team: "ops", contact: "ops@co.com")
      md = registry.markdown_exporter.export_skill("full.entry")
      expect(md).to include("full.entry")
      expect(md).to include("degraded")
      expect(md).to include("ops")
      expect(md).to include("service slow")
    end
  end

  describe "Concurrent-style sequential updates" do
    it "handles many rapid updates without state corruption" do
      registry.registrar.register(make_skill(name: "rapid.update", version: "1.0.0"))
      10.times do |i|
        registry.registrar.update("rapid.update", description: "Iteration #{i}", version: "1.0.#{i + 1}")
      end
      entry = registry.finder.find_by_name("rapid.update")
      expect(entry.skill.description).to eq("Iteration 9")
      expect(entry.skill.version).to eq("1.0.10")
    end
  end
end

# rubocop:enable Rails/DynamicFindBy, RSpec/DescribeClass, RSpec/MultipleExpectations
