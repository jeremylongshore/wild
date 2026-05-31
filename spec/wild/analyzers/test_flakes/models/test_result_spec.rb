# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Models::TestResult do
  subject(:result) do
    described_class.new(
      test_identity: identity,
      status: :passed,
      run_id: "run-001",
      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP,
      duration_ms: 12.5
    )
  end

  let(:identity) { make_identity }

  describe "#initialize" do
    it "stores all attributes" do
      expect(result.test_identity).to eq(identity)
      expect(result.status).to eq(:passed)
      expect(result.run_id).to eq("run-001")
      expect(result.duration_ms).to eq(12.5)
    end

    it "defaults metadata to empty hash" do
      expect(result.metadata).to eq({})
    end

    it "raises ArgumentError for invalid identity" do
      expect do
        described_class.new(
          test_identity: "not an identity",
          status: :passed,
          run_id: "run-001",
          timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP
        )
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for invalid status" do
      expect do
        described_class.new(
          test_identity: identity,
          status: :bogus,
          run_id: "run-001",
          timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP
        )
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for empty run_id" do
      expect do
        described_class.new(
          test_identity: identity,
          status: :passed,
          run_id: "",
          timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP
        )
      end.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for nil timestamp" do
      expect do
        described_class.new(
          test_identity: identity,
          status: :passed,
          run_id: "run-001",
          timestamp: nil
        )
      end.to raise_error(ArgumentError)
    end
  end

  describe "#passed?" do
    it "returns true when status is :passed" do
      expect(result.passed?).to be(true)
    end

    it "returns false when status is :failed" do
      r = make_result(status: :failed)
      expect(r.passed?).to be(false)
    end
  end

  describe "#failed?" do
    it "returns true when status is :failed" do
      r = make_result(status: :failed)
      expect(r.failed?).to be(true)
    end

    it "returns true when status is :errored" do
      r = make_result(status: :errored)
      expect(r.failed?).to be(true)
    end

    it "returns false when status is :passed" do
      expect(result.failed?).to be(false)
    end
  end

  describe "#skipped?" do
    it "returns true for :skipped" do
      r = make_result(status: :skipped)
      expect(r.skipped?).to be(true)
    end

    it "returns true for :pending" do
      r = make_result(status: :pending)
      expect(r.skipped?).to be(true)
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      h = result.to_h
      expect(h[:status]).to eq(:passed)
      expect(h[:run_id]).to eq("run-001")
      expect(h[:duration_ms]).to eq(12.5)
    end
  end
end
