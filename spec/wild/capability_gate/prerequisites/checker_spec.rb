# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Prerequisites::Checker do
  let(:check_result_class) { Wild::CapabilityGate::Prerequisites::CheckResult }

  def file_prereq(path:)
    Wild::CapabilityGate::Prerequisite.new(type: :file_exists, path: path)
  end

  def config_prereq(key:, value:)
    Wild::CapabilityGate::Prerequisite.new(type: :config_value, key: key, value: value)
  end

  describe "#check_all" do
    context "with no prerequisites" do
      it "returns a passed result with empty checked types" do
        checker = described_class.new
        result = checker.check_all([])

        expect(result).to be_satisfied
        expect(result.checked_types).to eq([])
      end
    end

    context "with a single passing prerequisite" do
      it "returns a passed result" do
        checker = described_class.new
        result = checker.check_all([file_prereq(path: __FILE__)])

        expect(result).to be_satisfied
        expect(result.checked_types).to eq(%i[file_exists])
      end
    end

    context "with a single failing prerequisite" do
      it "returns a failed result with details" do
        checker = described_class.new
        result = checker.check_all([file_prereq(path: "/nonexistent/file.md")])

        expect(result).not_to be_satisfied
        expect(result.checked_types).to eq(%i[file_exists])
        expect(result.details).to include("/nonexistent/file.md")
      end
    end

    context "with multiple prerequisites that all pass" do
      it "returns a passed result with all types checked" do
        checker = described_class.new(context: { admin_enabled: true })
        prerequisites = [
          file_prereq(path: __FILE__),
          config_prereq(key: "admin_enabled", value: true)
        ]

        result = checker.check_all(prerequisites)

        expect(result).to be_satisfied
        expect(result.checked_types).to eq(%i[file_exists config_value])
      end
    end

    context "with multiple prerequisites where the first fails" do
      it "short-circuits and only checks the first" do
        checker = described_class.new(context: { admin_enabled: true })
        prerequisites = [
          file_prereq(path: "/nonexistent/file.md"),
          config_prereq(key: "admin_enabled", value: true)
        ]

        result = checker.check_all(prerequisites)

        expect(result).not_to be_satisfied
        expect(result.checked_types).to eq(%i[file_exists])
        expect(result.details).to include("/nonexistent/file.md")
      end
    end

    context "with multiple prerequisites where the second fails" do
      it "checks both and reports the second failure" do
        checker = described_class.new(context: { admin_enabled: false })
        prerequisites = [
          file_prereq(path: __FILE__),
          config_prereq(key: "admin_enabled", value: true)
        ]

        result = checker.check_all(prerequisites)

        expect(result).not_to be_satisfied
        expect(result.checked_types).to eq(%i[file_exists config_value])
        expect(result.details).to include("admin_enabled")
      end
    end

    context "with context passed through" do
      it "makes context available to config_value checks" do
        checker = described_class.new(context: { "feature_flag" => "on" })
        result = checker.check_all([config_prereq(key: "feature_flag", value: "on")])

        expect(result).to be_satisfied
      end
    end
  end
end
