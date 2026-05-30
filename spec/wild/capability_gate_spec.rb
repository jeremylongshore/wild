# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate do
  # F1 collapsed nine per-namespace VERSION constants into one Wild::VERSION
  # at the gem level. The namespace inherits its version from the gem.
  it "inherits its version from the gem-level Wild::VERSION" do
    expect(Wild::VERSION).not_to be_nil
    expect(Wild::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "defines the Wild::CapabilityGate module" do
    expect(described_class).to be_a(Module)
  end
end
