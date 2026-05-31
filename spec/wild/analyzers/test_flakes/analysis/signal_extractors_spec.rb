# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Analysis::SignalExtractors do
  subject(:extractor) { extractor_class.new }

  let(:extractor_class) do
    Class.new do
      include Wild::Analyzers::TestFlakes::Analysis::SignalExtractors
    end
  end
  let(:base_record) { flake_record_with }

  describe "#timing_signal" do
    context "with high duration variance" do
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: make_identity,
          results: results_with_high_variance
        )
      end

      it "returns a score > 0" do
        expect(extractor.timing_signal(record)).to be > 0
      end
    end

    context "with uniform durations" do
      let(:record) do
        id = make_identity
        results = 5.times.map do |i|
          make_result(identity: id, duration_ms: 10.0, run_id: "run-#{i + 1}",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
        end
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(test_identity: id, results: results)
      end

      it "returns 0.0" do
        expect(extractor.timing_signal(record)).to eq(0.0)
      end
    end
  end

  describe "#shared_state_signal" do
    it "returns 0.0 when no other flakes in same file" do
      record = flake_record_with
      score = extractor.shared_state_signal(record, [record])
      expect(score).to eq(0.0)
    end

    it "returns a positive score when multiple flakes share a file" do
      id1 = make_identity(file_path: "spec/shared/foo_spec.rb", test_name: "test_a")
      id2 = make_identity(file_path: "spec/shared/foo_spec.rb", test_name: "test_b")
      id3 = make_identity(file_path: "spec/shared/foo_spec.rb", test_name: "test_c")

      records = [id1, id2, id3].map { |id| flake_record_with(identity: id) }
      score = extractor.shared_state_signal(records[0], records)
      expect(score).to be > 0
    end
  end

  describe "#external_dependency_signal" do
    context "with network error messages" do
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: make_identity,
          results: results_with_external_errors
        )
      end

      it "returns a high score" do
        expect(extractor.external_dependency_signal(record)).to be > 0.5
      end
    end

    context "with no error messages" do
      it "returns 0.0" do
        expect(extractor.external_dependency_signal(base_record)).to eq(0.0)
      end
    end
  end

  describe "#random_seed_signal" do
    context "with different seeds correlating to different outcomes" do
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: make_identity,
          results: results_with_seeds
        )
      end

      it "returns a high score" do
        expect(extractor.random_seed_signal(record)).to be > 0.5
      end
    end

    context "with no seed metadata" do
      it "returns low or zero score" do
        expect(extractor.random_seed_signal(base_record)).to be <= 0.5
      end
    end
  end

  describe "#timezone_locale_signal" do
    context "with timezone error messages" do
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: make_identity,
          results: results_with_timezone_errors
        )
      end

      it "returns a positive score" do
        expect(extractor.timezone_locale_signal(record)).to be > 0
      end
    end

    context "with no timezone-related errors" do
      it "returns 0.0" do
        expect(extractor.timezone_locale_signal(base_record)).to eq(0.0)
      end
    end
  end

  describe "#resource_contention_signal" do
    it "returns 0.0 with empty results_by_run" do
      expect(extractor.resource_contention_signal(base_record, {})).to eq(0.0)
    end

    context "when failures cluster with many other failures in same run" do
      let(:contention_record) do
        id = make_identity
        results = flaky_results(identity: id, pass_count: 3, fail_count: 3)
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(test_identity: id, results: results)
      end

      let(:contention_run_map) do
        contention_record.results.select(&:failed?).to_h do |r|
          [r.run_id, 10.times.map do |i|
            make_result(identity: make_identity(test_name: "other_test_#{i}"),
                        status: :failed, run_id: r.run_id,
                        timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
          end]
        end
      end

      it "returns a positive score" do
        score = extractor.resource_contention_signal(contention_record, contention_run_map)
        expect(score).to be > 0
      end
    end
  end
end
