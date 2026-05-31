# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Malformed input handling" do
  let(:registry) { Wild::Skillops.build }

  describe "Skill creation with invalid input" do
    it "rejects nil name" do
      expect { make_skill(name: nil) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects empty string name" do
      expect { make_skill(name: "") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects whitespace-only name" do
      expect { make_skill(name: "   ") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects version without dots" do
      expect { make_skill(version: "v1") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects non-semver version" do
      expect { make_skill(version: "latest") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects symbol as name" do
      expect { make_skill(name: :my_skill) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects integer as description" do
      expect { make_skill(description: 42) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects hash as tags" do
      expect { make_skill(tags: { tag: "value" }) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects unknown category symbol" do
      expect { make_skill(category: :marketing) }.to raise_error(Wild::Skillops::ValidationError)
    end
  end

  describe "Registrar with invalid input" do
    it "rejects nil argument to register" do
      expect { registry.registrar.register(nil) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects string argument to register" do
      expect { registry.registrar.register("skill-name") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects update on non-existent skill" do
      expect do
        registry.registrar.update("ghost.skill", description: "nope")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end

    it "rejects deprecate on non-existent skill" do
      expect do
        registry.registrar.deprecate("ghost.skill")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end

    it "rejects retire on non-existent skill" do
      expect do
        registry.registrar.retire("ghost.skill")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end

    it "rejects duplicate registration" do
      skill = make_skill
      registry.registrar.register(skill)
      expect do
        registry.registrar.register(make_skill)
      end.to raise_error(Wild::Skillops::DuplicateSkillError)
    end
  end

  describe "Health tracker with invalid input" do
    it "rejects unknown skill name" do
      expect do
        registry.health_tracker.record("ghost", state: :available)
      end.to raise_error(Wild::Skillops::NotFoundError)
    end

    it "rejects invalid health state" do
      registry.registrar.register(make_skill(name: "health.test"))
      expect do
        registry.health_tracker.record("health.test", state: :exploded)
      end.to raise_error(Wild::Skillops::ValidationError)
    end
  end

  describe "Dependency with invalid input" do
    it "rejects nil skill_name" do
      expect do
        Wild::Skillops::Models::Dependency.new(skill_name: nil, depends_on: "other")
      end.to raise_error(Wild::Skillops::ValidationError)
    end

    it "rejects invalid dependency_type" do
      expect do
        make_dependency(dependency_type: :maybe)
      end.to raise_error(Wild::Skillops::ValidationError)
    end
  end

  # The source gem's Configuration class did per-setter type validation
  # (raising InvalidConfigurationError on bad input). Wild's typed Struct
  # design dropped that machinery in the Role 5 move. The 4 validation
  # specs that lived here are deleted rather than rewritten to avoid
  # testing absent behavior (F3 — no vanity tests).
  #
  # If we re-add validation later (Role 6 follow-up bead), the specs come
  # back with it.
end

# rubocop:enable RSpec/DescribeClass
