# frozen_string_literal: true

RSpec.describe Wild::Analyzers::Permission::Models::Finding do
  describe "#initialize" do
    it "creates a finding with valid attributes" do
      f = described_class.new(type: :orphan_capability, severity: :warning, message: "Unused cap")
      expect(f.type).to eq(:orphan_capability)
      expect(f.severity).to eq(:warning)
      expect(f.message).to eq("Unused cap")
      expect(f.evidence).to eq({})
    end

    it "coerces string type to symbol" do
      f = described_class.new(type: "missing_reference", severity: :error, message: "msg")
      expect(f.type).to eq(:missing_reference)
    end

    it "coerces string severity to symbol" do
      f = described_class.new(type: :foo, severity: "info", message: "msg")
      expect(f.severity).to eq(:info)
    end

    it "freezes evidence hash" do
      f = described_class.new(type: :foo, severity: :info, message: "msg", evidence: { a: 1 })
      expect(f.evidence).to be_frozen
    end

    it "raises ArgumentError for invalid severity" do
      expect do
        described_class.new(type: :foo, severity: :bogus, message: "msg")
      end.to raise_error(ArgumentError, /Invalid severity/)
    end
  end

  describe "ordering" do
    let(:critical) { described_class.new(type: :foo, severity: :critical, message: "c") }
    let(:error)    { described_class.new(type: :foo, severity: :error, message: "e") }
    let(:warning)  { described_class.new(type: :foo, severity: :warning, message: "w") }
    let(:info)     { described_class.new(type: :foo, severity: :info, message: "i") }

    it "sorts critical before error before warning before info" do
      sorted = [info, warning, critical, error].sort
      expect(sorted.map(&:severity)).to eq(%i[critical error warning info])
    end
  end

  describe "all valid severities" do
    %i[info warning error critical].each do |sev|
      it "accepts #{sev}" do
        expect do
          described_class.new(type: :foo, severity: sev, message: "msg")
        end.not_to raise_error
      end
    end
  end
end
