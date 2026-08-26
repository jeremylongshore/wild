# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::Adapters::FlipperAdapter do
  # Plain `let`, not `subject(:adapter)`: this spec stubs the private
  # require_flipper! (the gem is not installed in this repo's bundle) which
  # RSpec/SubjectStub forbids on the declared subject.
  let(:adapter) { described_class.new }

  let(:fake_flipper) { Wild::AdminTools::TestSupport::FakeFlipper }

  before do
    fake_flipper::Registry.reset!
    stub_const("Flipper", fake_flipper::Registry)
    stub_const("Flipper::Actor", fake_flipper::Actor)
    # Gem not installed in this repo's bundle (see the SidekiqAdapter spec
    # for the same pattern): the real `require "flipper"` would LoadError.
    allow(adapter).to receive(:require_flipper!)
  end

  # Explicitly enable/disable (never just leave the default) so the fake
  # Feature registers itself into the Registry -- mere `Registry[name]`
  # read access does not persist (see fake_backends.rb).
  def seed_flag(name, enabled: false)
    feature = fake_flipper::Registry[name]
    enabled ? feature.enable : feature.disable
    feature
  end

  it_behaves_like "an admin tools adapter", Wild::AdminTools::Executor::Adapters::FlagAdapter

  describe "#read_flag" do
    it "returns nil for an unknown flag" do
      expect(adapter.read_flag("ghost")).to be_nil
    end

    it "returns the flag's enabled state, percentage, and actors" do
      seed_flag("beta", enabled: true)
      result = adapter.read_flag("beta")
      expect(result).to include(name: "beta", enabled: true, percentage: nil, actors: [])
    end
  end

  describe "#list_flags" do
    it "does not require any filter argument (abstract contract is **_options)" do
      expect { adapter.list_flags }.not_to raise_error
    end

    it "filters to only enabled flags when enabled_only: true" do
      seed_flag("on", enabled: true)
      seed_flag("off", enabled: false)
      result = adapter.list_flags(enabled_only: true)
      expect(result.pluck(:name)).to eq(["on"])
    end
  end

  describe "#toggle_flag!" do
    it "enables and disables a flag, auto-vivifying it like the real Flipper[] does" do
      expect(adapter.toggle_flag!("beta", true)).to eq(flag_name: "beta", enabled: true)
      expect(fake_flipper::Registry["beta"].enabled?).to be(true)

      adapter.toggle_flag!("beta", false)
      expect(fake_flipper::Registry["beta"].enabled?).to be(false)
    end
  end

  describe "#enable_for_actor! / #disable_for_actor!" do
    it "adds and removes a composite actor id" do
      seed_flag("beta")
      adapter.enable_for_actor!("beta", "User", "1")
      expect(fake_flipper::Registry["beta"].gates_hash[:actors]).to include("User;1")

      adapter.disable_for_actor!("beta", "User", "1")
      expect(fake_flipper::Registry["beta"].gates_hash[:actors]).not_to include("User;1")
    end
  end

  describe "#delete_flag!" do
    it "removes the flag from the registry" do
      seed_flag("beta")
      result = adapter.delete_flag!("beta")
      expect(result).to eq(flag_name: "beta", deleted: true)
      expect(fake_flipper::Registry.features.map(&:name)).not_to include("beta")
    end
  end
end
