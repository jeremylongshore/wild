# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Models::FlakeRecord do
  subject(:record) do
    described_class.new(test_identity: identity, results: results)
  end

  let(:identity) { make_identity }
  let(:results) { flaky_results(identity: identity, pass_count: 3, fail_count: 2) }

  describe "#initialize" do
    it "stores identity and results" do
      expect(record.test_identity).to eq(identity)
      expect(record.results.size).to eq(5)
    end

    it "raises ArgumentError for invalid identity" do
      expect { described_class.new(test_identity: "bad", results: results) }
        .to raise_error(ArgumentError)
    end

    it "raises ArgumentError for non-Array results" do
      expect { described_class.new(test_identity: identity, results: "bad") }
        .to raise_error(ArgumentError)
    end

    it "sets first_seen from earliest result" do
      expect(record.first_seen).not_to be_nil
    end

    it "sets last_seen from latest result" do
      expect(record.last_seen).not_to be_nil
    end
  end

  describe "#flake_rate" do
    it "calculates failure percentage" do
      expect(record.flake_rate).to eq(0.4)
    end

    it "returns 0.0 for empty results" do
      empty = described_class.new(test_identity: identity, results: [])
      expect(empty.flake_rate).to eq(0.0)
    end
  end

  describe "#total_runs" do
    it "returns the count of all results" do
      expect(record.total_runs).to eq(5)
    end
  end

  describe "#failure_count" do
    it "returns the count of failures" do
      expect(record.failure_count).to eq(2)
    end
  end

  describe "#pass_count" do
    it "returns the count of passes" do
      expect(record.pass_count).to eq(3)
    end
  end

  describe "#run_ids" do
    it "returns unique run IDs" do
      expect(record.run_ids.size).to eq(5)
    end
  end

  describe "#durations" do
    it "returns non-nil duration values" do
      expect(record.durations).to all(be_a(Numeric))
    end
  end

  describe "#duration_variance" do
    it "returns 0.0 for single result" do
      single = described_class.new(
        test_identity: identity,
        results: [make_result(identity: identity, duration_ms: 10.0)]
      )
      expect(single.duration_variance).to eq(0.0)
    end

    it "computes variance for multiple results" do
      high_var = described_class.new(
        test_identity: identity,
        results: results_with_high_variance(identity: identity)
      )
      expect(high_var.duration_variance).to be > 0
    end
  end

  describe "#primary_root_cause" do
    it "returns nil when no root causes" do
      expect(record.primary_root_cause).to be_nil
    end

    it "returns the cause with highest confidence" do
      cause1 = Wild::Analyzers::TestFlakes::Models::RootCause.new(category: :unknown, confidence: 0.3)
      cause2 = Wild::Analyzers::TestFlakes::Models::RootCause.new(category: :timing_dependent, confidence: 0.8)
      r = described_class.new(test_identity: identity, results: results, root_causes: [cause1, cause2])
      expect(r.primary_root_cause.category).to eq(:timing_dependent)
    end
  end

  describe "#to_h" do
    it "includes expected keys" do
      h = record.to_h
      expect(h).to include(:test_identity, :flake_rate, :total_runs, :failure_count)
    end
  end
end
