# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::RegistryEntry do
  let(:skill) { make_skill }
  let(:entry) { make_entry(skill: skill) }

  describe "#initialize" do
    it "creates with a skill and defaults" do
      expect(entry.skill).to eq(skill)
      expect(entry.versions).to eq([])
      expect(entry.health_status).to be_nil
      expect(entry.owner).to be_nil
      expect(entry.dependencies).to eq([])
    end

    it "raises ValidationError for non-Skill argument" do
      expect do
        described_class.new(skill: "not a skill")
      end.to raise_error(Wild::Skillops::ValidationError, /Skill instance/)
    end
  end

  describe "#name" do
    it "delegates to skill.name" do
      expect(entry.name).to eq(skill.name)
    end
  end

  describe "#lifecycle_state" do
    it "delegates to skill.lifecycle_state" do
      expect(entry.lifecycle_state).to eq(skill.lifecycle_state)
    end
  end

  describe "#healthy?" do
    it "returns false when health_status is nil" do
      expect(entry.healthy?).to be false
    end

    it "returns true when health_status state is available" do
      hs = make_health(skill_name: skill.name, state: :available)
      e = make_entry(skill: skill, health_status: hs)
      expect(e.healthy?).to be true
    end

    it "returns false when health_status state is degraded" do
      hs = make_health(skill_name: skill.name, state: :degraded)
      e = make_entry(skill: skill, health_status: hs)
      expect(e.healthy?).to be false
    end
  end

  describe "#to_h" do
    it "returns a Hash with skill, versions, health_status, owner, dependencies" do
      h = entry.to_h
      expect(h).to include(:skill, :versions, :health_status, :owner, :dependencies)
    end

    it "serializes nested objects" do
      hs = make_health(skill_name: skill.name)
      e = make_entry(skill: skill, health_status: hs)
      expect(e.to_h[:health_status]).to include(:state, :skill_name)
    end
  end
end
