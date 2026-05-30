# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Prerequisites::FileExistsChecker do
  let(:check_result_class) { Wild::CapabilityGate::Prerequisites::CheckResult }

  def prereq(path:)
    Wild::CapabilityGate::Prerequisite.new(type: :file_exists, path: path)
  end

  describe ".check" do
    context "when the file exists" do
      it "returns a passed result" do
        result = described_class.check(prereq(path: __FILE__))

        expect(result).to be_satisfied
        expect(result.details).to be_nil
      end
    end

    context "when the file does not exist" do
      it "returns a failed result with details" do
        result = described_class.check(prereq(path: "/nonexistent/attestation.md"))

        expect(result).not_to be_satisfied
        expect(result.details).to include("/nonexistent/attestation.md")
        expect(result.details).to include("required file not found")
      end
    end

    context "when path is nil" do
      it "returns a failed result" do
        bad_prereq = Wild::CapabilityGate::Prerequisite.new(type: :file_exists)
        result = described_class.check(bad_prereq)

        expect(result).not_to be_satisfied
        expect(result.details).to include("missing required path parameter")
      end
    end

    context "when path is empty string" do
      it "returns a failed result" do
        result = described_class.check(prereq(path: ""))

        expect(result).not_to be_satisfied
        expect(result.details).to include("missing required path parameter")
      end
    end

    it "does not raise on errors (fail-closed)" do
      bad_prereq = instance_double(Wild::CapabilityGate::Prerequisite, type: :file_exists, params: nil)
      result = described_class.check(bad_prereq)

      expect(result).not_to be_satisfied
      expect(result.details).to include("file_exists check failed")
    end
  end
end
