# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe Wild::Analyzers::Permission do
  # F1 collapsed nine per-namespace VERSION constants into one gem-level
  # Wild::VERSION. The namespace inherits its version from the gem.
  it "inherits its version from the gem-level Wild::VERSION" do
    expect(Wild::VERSION).not_to be_nil
    expect(Wild::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  # Real analyzer-by-analyzer coverage lives under
  # spec/wild/analyzers/permission/**. This top-level spec's job (review
  # wave finding f-x2-7: previously two vanity examples, VERSION format +
  # "is a Module") is to smoke-test the namespace's public entry point,
  # .audit, end to end.
  describe ".audit" do
    it "raises a configuration error rather than silently no-opping when no paths are set" do
      allow(Wild.config.analyzers.permission).to receive_messages(capabilities_path: nil, grants_path: nil)

      expect { described_class.audit }.to raise_error(Wild::ConfigurationError, /capabilities_path must be set/)
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
