# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::Dependency do
  describe "#initialize" do
    it "creates with valid required dependency" do
      dep = make_dependency
      expect(dep.skill_name).to eq("introspect.schema")
      expect(dep.depends_on).to eq("admin.reindex")
      expect(dep.dependency_type).to eq(:required)
      expect(dep.description).to be_nil
    end

    it "accepts optional dependency type" do
      dep = make_dependency(dependency_type: :optional)
      expect(dep.dependency_type).to eq(:optional)
    end

    it "accepts a description string" do
      dep = make_dependency(description: "Needs admin up first")
      expect(dep.description).to eq("Needs admin up first")
    end

    it "raises ValidationError for blank skill_name" do
      expect { make_dependency(skill_name: "") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises ValidationError for blank depends_on" do
      expect { make_dependency(depends_on: "") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises ValidationError for invalid dependency_type" do
      expect do
        make_dependency(dependency_type: :unknown)
      end.to raise_error(Wild::Skillops::ValidationError, /dependency_type/)
    end

    it "raises ValidationError for non-String description" do
      expect do
        make_dependency(description: 42)
      end.to raise_error(Wild::Skillops::ValidationError, /description/)
    end
  end

  describe "#to_h" do
    it "includes all fields" do
      dep = make_dependency(description: "test dep")
      h = dep.to_h
      expect(h).to include(:skill_name, :depends_on, :dependency_type, :description)
      expect(h[:description]).to eq("test dep")
    end
  end
end
