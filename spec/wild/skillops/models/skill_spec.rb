# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::Skill do
  describe "#initialize" do
    it "creates a skill with valid attributes" do
      skill = make_skill
      expect(skill.name).to eq("introspect.schema")
      expect(skill.version).to eq("1.0.0")
      expect(skill.category).to eq(:introspection)
      expect(skill.lifecycle_state).to eq(:draft)
    end

    it "strips whitespace from name" do
      skill = make_skill(name: "  my.skill  ")
      expect(skill.name).to eq("my.skill")
    end

    it "downcases and strips tags" do
      skill = make_skill(tags: ["Rails", " Admin "])
      expect(skill.tags).to eq(%w[rails admin])
    end

    it "accepts all valid categories" do
      described_class::VALID_CATEGORIES.each do |cat|
        expect { make_skill(category: cat) }.not_to raise_error
      end
    end

    it "uses Time.now.utc as registered_at when not provided" do
      skill = make_skill(registered_at: nil)
      expect(skill.registered_at).to be_a(Time)
    end

    it "raises ValidationError for blank name" do
      expect { make_skill(name: "  ") }.to raise_error(Wild::Skillops::ValidationError, /name/)
    end

    it "raises ValidationError for non-String name" do
      expect { make_skill(name: 42) }.to raise_error(Wild::Skillops::ValidationError, /name/)
    end

    it "raises ValidationError for blank description" do
      expect { make_skill(description: "") }.to raise_error(Wild::Skillops::ValidationError, /description/)
    end

    it "raises ValidationError for blank repo" do
      expect { make_skill(repo: "") }.to raise_error(Wild::Skillops::ValidationError, /repo/)
    end

    it "raises ValidationError for invalid version format" do
      expect { make_skill(version: "not-semver") }.to raise_error(Wild::Skillops::ValidationError, /semver/)
    end

    it "raises ValidationError for non-Array tags" do
      expect { make_skill(tags: "tag") }.to raise_error(Wild::Skillops::ValidationError, /tags/)
    end

    it "raises ValidationError for tags containing non-Strings" do
      expect { make_skill(tags: [:symbol]) }.to raise_error(Wild::Skillops::ValidationError, /tags/)
    end

    it "raises ValidationError for invalid category" do
      expect { make_skill(category: :unknown_cat) }.to raise_error(Wild::Skillops::ValidationError, /category/)
    end
  end

  describe "#to_h" do
    it "returns a Hash with expected keys" do
      skill = make_skill
      h = skill.to_h
      expect(h).to include(
        :name, :description, :repo, :version, :tags,
        :category, :capabilities_required, :lifecycle_state, :registered_at
      )
    end

    it "serializes registered_at as ISO 8601 string" do
      skill = make_skill
      expect(skill.to_h[:registered_at]).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end

  describe "#==" do
    it "is equal to another Skill with the same name" do
      a = make_skill(name: "foo.bar")
      b = make_skill(name: "foo.bar", version: "2.0.0")
      expect(a).to eq(b)
    end

    it "is not equal to a Skill with a different name" do
      expect(make_skill(name: "a.b")).not_to eq(make_skill(name: "c.d"))
    end
  end
end
