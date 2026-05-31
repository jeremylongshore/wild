# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Models::TriageEntry do
  subject(:entry) do
    described_class.new(
      flake_record: record,
      severity: :high,
      severity_score: 0.65,
      remediations: ["Add retry logic"],
      trend: :worsening
    )
  end

  let(:record) { flake_record_with }

  describe "#initialize" do
    it "stores all attributes" do
      expect(entry.severity).to eq(:high)
      expect(entry.severity_score).to eq(0.65)
      expect(entry.trend).to eq(:worsening)
      expect(entry.remediations).to eq(["Add retry logic"])
    end

    it "raises ArgumentError for invalid flake_record" do
      expect do
        described_class.new(
          flake_record: "bad",
          severity: :high,
          severity_score: 0.5
        )
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for invalid severity" do
      expect do
        described_class.new(
          flake_record: record,
          severity: :catastrophic,
          severity_score: 0.5
        )
      end.to raise_error(ArgumentError)
    end
  end

  describe "#test_identity" do
    it "delegates to flake_record" do
      expect(entry.test_identity).to eq(record.test_identity)
    end
  end

  describe "#critical?" do
    it "returns false for high severity" do
      expect(entry.critical?).to be(false)
    end

    it "returns true for critical severity" do
      e = described_class.new(flake_record: record, severity: :critical, severity_score: 0.9)
      expect(e.critical?).to be(true)
    end
  end

  describe "#high?" do
    it "returns true for high severity" do
      expect(entry.high?).to be(true)
    end
  end

  describe "#to_h" do
    it "includes severity and flake data" do
      h = entry.to_h
      expect(h[:severity]).to eq(:high)
      expect(h[:trend]).to eq(:worsening)
      expect(h[:remediations]).to eq(["Add retry logic"])
    end
  end
end
