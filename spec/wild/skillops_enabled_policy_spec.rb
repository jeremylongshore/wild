# frozen_string_literal: true

RSpec.describe Wild::Skillops do
  it "rejects the public factory while the internal namespace is disabled" do
    Wild.reset_config!

    expect { described_class.build }
      .to raise_error(Wild::Skillops::DisabledError, /disabled by default/)
  end

  it "builds only after an application explicitly opts in" do
    Wild.configure { |settings| settings.skillops.enabled = true }

    expect(described_class.build).to be_a(Wild::Skillops::RegistryFacade)
  end
end
