# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::SkillVersion do
  describe "#initialize" do
    it "creates with valid attributes" do
      sv = make_skill_version
      expect(sv.skill_name).to eq("introspect.schema")
      expect(sv.version).to eq("1.0.0")
      expect(sv.changes).to eq(["Initial registration"])
    end

    it "defaults created_at to now when not provided" do
      sv = described_class.new(skill_name: "foo", version: "1.0.0")
      expect(sv.created_at).to be_a(Time)
    end

    it "defaults changes to empty array" do
      sv = described_class.new(skill_name: "foo", version: "1.0.0")
      expect(sv.changes).to eq([])
    end

    it "raises ValidationError for blank skill_name" do
      expect do
        described_class.new(skill_name: "", version: "1.0.0")
      end.to raise_error(Wild::Skillops::ValidationError, /skill_name/)
    end

    it "raises ValidationError for blank version" do
      expect do
        described_class.new(skill_name: "foo", version: "")
      end.to raise_error(Wild::Skillops::ValidationError, /version/)
    end

    it "raises ValidationError for non-Array changes" do
      expect do
        described_class.new(skill_name: "foo", version: "1.0.0", changes: "bad")
      end.to raise_error(Wild::Skillops::ValidationError, /changes/)
    end
  end

  describe "#to_h" do
    it "includes all fields" do
      sv = make_skill_version
      h = sv.to_h
      expect(h).to include(:skill_name, :version, :changes, :created_at)
    end
  end
end
