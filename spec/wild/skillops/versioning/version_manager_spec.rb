# frozen_string_literal: true

RSpec.describe Wild::Skillops::Versioning::VersionManager do
  let(:registry) { build_registry }
  let(:vm) { registry.version_manager }

  before do
    registry.registrar.register(make_skill(name: "my.skill", version: "1.0.0"))
  end

  describe "#record_version" do
    it "records a version for an existing skill" do
      sv = vm.record_version("my.skill", "1.1.0", changes: ["Added feature"])
      expect(sv.version).to eq("1.1.0")
      expect(sv.changes).to eq(["Added feature"])
    end

    it "raises NotFoundError for unknown skill" do
      expect do
        vm.record_version("nope", "1.0.0")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end

    it "raises VersionCapacityError when version limit is reached" do
      Wild.configure { |c| c.skillops.max_versions_per_skill = 2 }
      # Initial registration already recorded one version
      vm.record_version("my.skill", "1.1.0", changes: ["v1.1"])
      expect do
        vm.record_version("my.skill", "1.2.0", changes: ["v1.2"])
      end.to raise_error(Wild::Skillops::VersionCapacityError)
    end
  end

  describe "#versions_for" do
    it "returns all recorded versions for a skill" do
      vm.record_version("my.skill", "1.1.0", changes: ["change"])
      expect(vm.versions_for("my.skill").size).to eq(2)
    end

    it "returns empty array for skill with no extra versions" do
      reg = build_registry
      skill = make_skill(name: "fresh.skill")
      reg.registrar.register(skill)
      # Only the initial registration version exists
      expect(reg.version_manager.versions_for("fresh.skill").size).to eq(1)
    end
  end

  describe "#latest_version" do
    it "returns the most recently recorded version" do
      vm.record_version("my.skill", "2.0.0", changes: ["major"])
      expect(vm.latest_version("my.skill").version).to eq("2.0.0")
    end
  end

  describe "#version_count" do
    it "returns number of versions" do
      vm.record_version("my.skill", "1.1.0")
      expect(vm.version_count("my.skill")).to eq(2)
    end
  end
end
