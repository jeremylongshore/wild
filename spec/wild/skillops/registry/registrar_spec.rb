# frozen_string_literal: true

RSpec.describe Wild::Skillops::Registry::Registrar do
  let(:registry) { build_registry }
  let(:registrar) { registry.registrar }

  describe "#register" do
    it "registers a new skill and returns a RegistryEntry" do
      skill = make_skill
      entry = registrar.register(skill)
      expect(entry).to be_a(Wild::Skillops::Models::RegistryEntry)
      expect(entry.name).to eq(skill.name)
    end

    it "records an initial version" do
      skill = make_skill
      registrar.register(skill)
      versions = registry.version_manager.versions_for(skill.name)
      expect(versions.size).to eq(1)
      expect(versions.first.changes).to include("Initial registration")
    end

    it "indexes tags for discovery" do
      skill = make_skill(tags: %w[alpha beta])
      registrar.register(skill)
      expect(registry.tag_index.lookup("alpha")).to include(skill.name)
    end

    it "raises DuplicateSkillError when the same name is registered twice" do
      registrar.register(make_skill)
      expect do
        registrar.register(make_skill)
      end.to raise_error(Wild::Skillops::DuplicateSkillError)
    end

    it "raises ValidationError for non-Skill argument" do
      expect { registrar.register("not a skill") }.to raise_error(Wild::Skillops::ValidationError)
    end
  end

  describe "#update" do
    it "updates skill attributes" do
      registrar.register(make_skill(name: "update.me", description: "Old desc"))
      entry = registrar.update("update.me", description: "New desc")
      expect(entry.skill.description).to eq("New desc")
    end

    it "records a new version when version changes" do
      registrar.register(make_skill(name: "bump.me", version: "1.0.0"))
      registrar.update("bump.me", version: "1.1.0")
      versions = registry.version_manager.versions_for("bump.me")
      expect(versions.last.version).to eq("1.1.0")
    end

    it "reindexes tags when tags change" do
      registrar.register(make_skill(name: "tag.me", tags: ["old-tag"]))
      registrar.update("tag.me", tags: ["new-tag"])
      expect(registry.tag_index.lookup("new-tag")).to include("tag.me")
      expect(registry.tag_index.lookup("old-tag")).not_to include("tag.me")
    end

    it "raises NotFoundError for unknown skill" do
      expect { registrar.update("nope", description: "x") }.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#deprecate" do
    it "transitions an active skill to deprecated" do
      registrar.register(make_skill(name: "dep.me", lifecycle_state: :draft))
      registrar.update("dep.me", lifecycle_state: :active)
      entry = registrar.deprecate("dep.me", reason: "superseded")
      expect(entry.skill.lifecycle_state).to eq(:deprecated)
    end

    it "raises LifecycleError when deprecating a draft skill" do
      registrar.register(make_skill(name: "still.draft"))
      expect do
        registrar.deprecate("still.draft")
      end.to raise_error(Wild::Skillops::LifecycleError)
    end
  end

  describe "#retire" do
    it "transitions a deprecated skill to retired" do
      registrar.register(make_skill(name: "retire.me", lifecycle_state: :draft))
      registrar.update("retire.me", lifecycle_state: :active)
      registrar.deprecate("retire.me")
      entry = registrar.retire("retire.me")
      expect(entry.skill.lifecycle_state).to eq(:retired)
    end

    it "raises LifecycleError when retiring an active skill" do
      registrar.register(make_skill(name: "active.skill", lifecycle_state: :draft))
      registrar.update("active.skill", lifecycle_state: :active)
      expect do
        registrar.retire("active.skill")
      end.to raise_error(Wild::Skillops::LifecycleError)
    end
  end
end
