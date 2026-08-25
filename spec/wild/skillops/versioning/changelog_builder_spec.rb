# frozen_string_literal: true

RSpec.describe Wild::Skillops::Versioning::ChangelogBuilder do
  let(:registry) { build_registry }
  let(:builder)  { registry.changelog_builder }

  before do
    registry.registrar.register(make_skill(name: "changelog.test", version: "1.0.0"))
    registry.version_manager.record_version("changelog.test", "1.1.0", changes: ["Added X"])
    registry.version_manager.record_version("changelog.test", "1.2.0", changes: ["Fixed Y", "Improved Z"])
  end

  describe "#build" do
    it "returns an Array of changelog lines" do
      lines = builder.build("changelog.test")
      expect(lines).to be_an(Array)
      expect(lines.size).to eq(3)
    end

    it "returns newest version first" do
      lines = builder.build("changelog.test")
      expect(lines.first).to include("1.2.0")
      expect(lines.last).to include("1.0.0")
    end

    it "raises NotFoundError for skill with no versions" do
      vm = registry.version_manager
      # Manually access a name that has no recorded versions
      allow(vm).to receive(:versions_for).with("ghost").and_return([])
      expect do
        builder.build("ghost")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#build_text" do
    it "returns a newline-joined String" do
      text = builder.build_text("changelog.test")
      expect(text).to be_a(String)
      expect(text).to include("1.2.0")
      expect(text).to include("Fixed Y; Improved Z")
    end
  end
end
