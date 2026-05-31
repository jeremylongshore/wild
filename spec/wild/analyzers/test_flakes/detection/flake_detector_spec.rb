# frozen_string_literal: true

# rubocop:disable Layout/LineLength

RSpec.describe Wild::Analyzers::TestFlakes::Detection::FlakeDetector do
  subject(:detector) { described_class.new }

  describe "#detect" do
    context "with a clearly flaky test" do
      let(:identity) { make_identity }
      let(:results) { flaky_results(identity: identity, pass_count: 4, fail_count: 2) }

      it "returns a FlakeRecord for the flaky test" do
        records = detector.detect(results)
        expect(records.size).to eq(1)
        expect(records.first).to be_a(Wild::Analyzers::TestFlakes::Models::FlakeRecord)
      end

      it "captures the correct identity" do
        records = detector.detect(results)
        expect(records.first.test_identity).to eq(identity)
      end

      it "captures all results in the record" do
        records = detector.detect(results)
        expect(records.first.total_runs).to eq(6)
      end
    end

    context "with a stable passing test" do
      let(:identity) { make_identity }
      let(:results) do
        5.times.map do |i|
          make_result(identity: identity, status: :passed, run_id: "run-#{i + 1}",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
        end
      end

      it "returns no flake records" do
        records = detector.detect(results)
        expect(records).to be_empty
      end
    end

    context "with insufficient runs" do
      let(:identity) { make_identity }
      let(:results) do
        [
          make_result(identity: identity, status: :passed, run_id: "run-1",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP),
          make_result(identity: identity, status: :failed, run_id: "run-2",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600)
        ]
      end

      it "ignores tests with fewer than minimum_runs" do
        records = detector.detect(results)
        expect(records).to be_empty
      end
    end

    context "with flake_rate below threshold" do
      let(:identity) { make_identity }

      it "ignores tests below the flake threshold" do
        # 1 failure out of 20 runs = 5%, below default 10% threshold
        results = 19.times.map do |i|
          make_result(identity: identity, status: :passed, run_id: "run-#{i + 1}",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
        end
        results << make_result(identity: identity, status: :failed, run_id: "run-20",
                               timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (19 * 3600))

        records = detector.detect(results)
        expect(records).to be_empty
      end
    end

    context "with multiple tests" do
      let(:stable_identity) { make_identity(test_name: "test_a") }
      let(:flaky_identity_b) { make_identity(test_name: "test_b") }
      let(:flaky_identity_c) { make_identity(test_name: "test_c") }

      it "detects only the flaky tests" do
        stable_results = 5.times.map do |i|
          make_result(identity: stable_identity, status: :passed, run_id: "run-#{i + 1}",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
        end
        flaky_b = flaky_results(identity: flaky_identity_b, pass_count: 3, fail_count: 2)
        flaky_c = flaky_results(identity: flaky_identity_c, pass_count: 2, fail_count: 3)

        records = detector.detect(stable_results + flaky_b + flaky_c)
        expect(records.map { |r| r.test_identity.test_name }).to contain_exactly("test_b", "test_c")
      end
    end

    context "with custom thresholds" do
      let(:detector) { described_class.new(minimum_runs: 2, flake_rate_threshold: 0.4) }
      let(:identity) { make_identity }

      it "uses configured minimum_runs" do
        results = [
          make_result(identity: identity, status: :passed, run_id: "run-1",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP),
          make_result(identity: identity, status: :failed, run_id: "run-2",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600)
        ]
        records = detector.detect(results)
        expect(records.size).to eq(1)
      end
    end

    context "with empty input" do
      it "returns empty array" do
        expect(detector.detect([])).to eq([])
      end
    end

    context "with invalid input" do
      it "raises DetectionError" do
        expect { detector.detect("bad") }
          .to raise_error(Wild::Analyzers::TestFlakes::DetectionError)
      end
    end
  end
end

# rubocop:enable Layout/LineLength
