# frozen_string_literal: true

RSpec.describe Wild::Skillops::Governance::LifecycleManager do
  subject(:lm) { described_class.new }

  describe "#transition!" do
    it "allows draft -> active" do
      expect(lm.transition!(:draft, :active)).to eq(:active)
    end

    it "allows draft -> retired" do
      expect(lm.transition!(:draft, :retired)).to eq(:retired)
    end

    it "allows active -> deprecated" do
      expect(lm.transition!(:active, :deprecated)).to eq(:deprecated)
    end

    it "allows deprecated -> retired" do
      expect(lm.transition!(:deprecated, :retired)).to eq(:retired)
    end

    it "raises LifecycleError for draft -> deprecated" do
      expect do
        lm.transition!(:draft, :deprecated)
      end.to raise_error(Wild::Skillops::LifecycleError)
    end

    it "raises LifecycleError for active -> retired" do
      expect do
        lm.transition!(:active, :retired)
      end.to raise_error(Wild::Skillops::LifecycleError)
    end

    it "raises LifecycleError for retired -> any" do
      expect do
        lm.transition!(:retired, :active)
      end.to raise_error(Wild::Skillops::LifecycleError)
    end

    it "raises LifecycleError for active -> draft" do
      expect do
        lm.transition!(:active, :draft)
      end.to raise_error(Wild::Skillops::LifecycleError)
    end
  end

  describe "#allowed_transitions" do
    it "returns correct transitions for each state" do
      expect(lm.allowed_transitions(:draft)).to match_array(%i[active retired])
      expect(lm.allowed_transitions(:active)).to eq(%i[deprecated])
      expect(lm.allowed_transitions(:deprecated)).to eq(%i[retired])
      expect(lm.allowed_transitions(:retired)).to eq([])
    end
  end

  describe "#terminal?" do
    it "returns true for retired state" do
      expect(lm.terminal?(:retired)).to be true
    end

    it "returns false for non-terminal states" do
      expect(lm.terminal?(:draft)).to be false
      expect(lm.terminal?(:active)).to be false
      expect(lm.terminal?(:deprecated)).to be false
    end
  end
end
