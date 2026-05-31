# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe Wild::Analyzers::Permission do
  # F1 collapsed nine per-namespace VERSION constants into one gem-level
  # Wild::VERSION. The namespace inherits its version from the gem.
  it "inherits its version from the gem-level Wild::VERSION" do
    expect(Wild::VERSION).not_to be_nil
    expect(Wild::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "defines the Wild::Analyzers::Permission module" do
    expect(described_class).to be_a(Module)
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
