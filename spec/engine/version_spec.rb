# frozen_string_literal: true

RSpec.describe Wild do
  it "has a version number" do
    expect(Wild::VERSION).to be_a(String)
    expect(Wild::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  describe ".configure" do
    it "yields the singleton configuration" do
      yielded = nil
      Wild.configure { |c| yielded = c }
      expect(yielded).to equal(Wild.config)
    end

    it "returns the configuration" do
      expect(Wild.configure).to equal(Wild.config)
    end
  end

  describe ".config" do
    it "exposes the seven namespace nested accessors declared in Configuration::NAMESPACES" do
      expect(Wild::Configuration::NAMESPACES).to contain_exactly(
        :introspection,
        :admin_tools,
        :capability_gate,
        :telemetry,
        :hooks,
        :analyzers,
        :skillops
      )
      Wild::Configuration::NAMESPACES.each do |ns|
        expect(Wild.config.public_send(ns)).not_to be_nil
      end
    end
  end
end
