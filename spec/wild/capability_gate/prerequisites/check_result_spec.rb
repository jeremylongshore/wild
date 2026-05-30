# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Prerequisites::CheckResult do
  describe ".passed" do
    it "is satisfied" do
      result = described_class.passed
      expect(result).to be_satisfied
    end

    it "has no details" do
      result = described_class.passed
      expect(result.details).to be_nil
    end

    it "records checked types" do
      result = described_class.passed(checked_types: %i[file_exists config_value])
      expect(result.checked_types).to eq(%i[file_exists config_value])
    end

    it "is frozen" do
      result = described_class.passed
      expect(result).to be_frozen
      expect(result.checked_types).to be_frozen
    end
  end

  describe ".failed" do
    it "is not satisfied" do
      result = described_class.failed(details: "missing file")
      expect(result).not_to be_satisfied
    end

    it "carries failure details" do
      result = described_class.failed(details: "required file not found: /tmp/foo")
      expect(result.details).to eq("required file not found: /tmp/foo")
    end

    it "records checked types up to and including the failure" do
      result = described_class.failed(checked_types: %i[file_exists], details: "missing")
      expect(result.checked_types).to eq(%i[file_exists])
    end

    it "is frozen" do
      result = described_class.failed(details: "fail")
      expect(result).to be_frozen
    end
  end
end
