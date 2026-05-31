# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Detection::Comparator do
  subject(:comparator) { described_class.new }

  describe "#group_by_identity" do
    let(:identity_a) { make_identity(test_name: "test_a") }
    let(:identity_b) { make_identity(test_name: "test_b") }

    it "groups results by identity key" do
      results = [
        make_result(identity: identity_a, run_id: "run-1"),
        make_result(identity: identity_a, run_id: "run-2"),
        make_result(identity: identity_b, run_id: "run-1")
      ]
      grouped = comparator.group_by_identity(results)
      expect(grouped.keys.size).to eq(2)
      expect(grouped[identity_a.key].size).to eq(2)
    end

    it "raises DetectionError for non-Array input" do
      expect { comparator.group_by_identity("bad") }
        .to raise_error(Wild::Analyzers::TestFlakes::DetectionError)
    end

    it "skips non-TestResult objects" do
      results = [make_result, "not a result", nil]
      grouped = comparator.group_by_identity(results)
      expect(grouped.size).to eq(1)
    end
  end

  describe "#both_outcomes?" do
    it "returns true when results have both pass and fail" do
      results = [make_result(status: :passed), make_result(status: :failed)]
      expect(comparator.both_outcomes?(results)).to be(true)
    end

    it "returns false when only passes" do
      results = [make_result(status: :passed), make_result(status: :passed)]
      expect(comparator.both_outcomes?(results)).to be(false)
    end

    it "returns false when only failures" do
      results = [make_result(status: :failed), make_result(status: :failed)]
      expect(comparator.both_outcomes?(results)).to be(false)
    end

    it "treats :errored as failed" do
      results = [make_result(status: :passed), make_result(status: :errored)]
      expect(comparator.both_outcomes?(results)).to be(true)
    end
  end

  describe "#flake_rate" do
    it "calculates proportion of failures" do
      results = [
        make_result(status: :passed),
        make_result(status: :passed),
        make_result(status: :failed)
      ]
      expect(comparator.flake_rate(results)).to be_within(0.001).of(1.0 / 3.0)
    end

    it "returns 0.0 for empty array" do
      expect(comparator.flake_rate([])).to eq(0.0)
    end
  end

  describe "#run_ids_with_failures" do
    it "returns IDs from failed runs only" do
      results = [
        make_result(status: :passed, run_id: "run-1"),
        make_result(status: :failed, run_id: "run-2"),
        make_result(status: :failed, run_id: "run-2")
      ]
      expect(comparator.run_ids_with_failures(results)).to eq(["run-2"])
    end
  end

  describe "#run_ids_with_passes" do
    it "returns IDs from passing runs only" do
      results = [
        make_result(status: :passed, run_id: "run-1"),
        make_result(status: :failed, run_id: "run-2")
      ]
      expect(comparator.run_ids_with_passes(results)).to eq(["run-1"])
    end
  end

  describe ".group_by_identity class method" do
    it "delegates to instance method" do
      results = [make_result]
      grouped = described_class.group_by_identity(results)
      expect(grouped).to be_a(Hash)
    end
  end
end
