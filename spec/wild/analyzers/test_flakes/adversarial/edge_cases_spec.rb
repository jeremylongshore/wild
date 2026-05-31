# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, Layout/LineLength

RSpec.describe "Edge case handling" do
  let(:detector) { Wild::Analyzers::TestFlakes::Detection::FlakeDetector.new(minimum_runs: 2) }
  let(:analyzer) { Wild::Analyzers::TestFlakes::Analysis::RootCauseAnalyzer.new }
  let(:engine) { Wild::Analyzers::TestFlakes::Triage::Engine.new }

  describe "special characters in test names" do
    let(:special_chars) do
      [
        "test with 'single quotes'",
        'test with "double quotes"',
        "test with <brackets>",
        "test with & ampersand",
        "test with\nnewline",
        "test with | pipe",
        "test with `backtick`"
      ]
    end

    it "handles special characters in test names without raising" do
      results = special_chars.flat_map do |name|
        id = make_identity(test_name: name)
        [
          make_result(identity: id, status: :passed, run_id: "run-1",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP),
          make_result(identity: id, status: :failed, run_id: "run-2",
                      timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600)
        ]
      end
      expect { detector.detect(results) }.not_to raise_error
    end

    it "handles special characters in markdown export" do
      id = make_identity(test_name: "test with | pipe and `backtick`")
      record = flake_record_with(identity: id)
      entry = Wild::Analyzers::TestFlakes::Models::TriageEntry.new(
        flake_record: record, severity: :high, severity_score: 0.6
      )
      exporter = Wild::Analyzers::TestFlakes::Export::MarkdownExporter.new
      expect { exporter.export([entry]) }.not_to raise_error
    end
  end

  describe "large result sets" do
    it "handles 1000 results without error" do
      results = 100.times.flat_map do |test_i|
        id = make_identity(test_name: "test_#{test_i}", file_path: "spec/test_#{test_i}_spec.rb")
        10.times.map do |run_i|
          status = test_i % 3 == 0 && run_i % 3 == 0 ? :failed : :passed
          make_result(
            identity: id,
            status: status,
            run_id: "run-#{run_i + 1}",
            timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (run_i * 3600)
          )
        end
      end

      expect { detector.detect(results) }.not_to raise_error
    end

    it "processes 1000 results in a reasonable time" do
      results = 200.times.flat_map do |i|
        id = make_identity(test_name: "test_#{i}")
        5.times.map do |j|
          make_result(
            identity: id,
            status: i % 4 == 0 ? :failed : :passed,
            run_id: "run-#{j + 1}",
            timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (j * 3600)
          )
        end
      end

      start = Time.now.utc
      detector.detect(results)
      elapsed = Time.now.utc - start
      expect(elapsed).to be < 5.0
    end
  end

  describe "boundary conditions" do
    it "handles exactly minimum_runs results" do
      id = make_identity
      results = [
        make_result(identity: id, status: :passed, run_id: "run-1",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP),
        make_result(identity: id, status: :passed, run_id: "run-2",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600),
        make_result(identity: id, status: :failed, run_id: "run-3",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 7200)
      ]
      records = detector.detect(results)
      expect(records.size).to eq(1)
    end

    it "handles zero duration gracefully" do
      id = make_identity
      results = [
        make_result(identity: id, status: :passed, run_id: "run-1",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP, duration_ms: 0.0),
        make_result(identity: id, status: :failed, run_id: "run-2",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600, duration_ms: 0.0)
      ]
      record = Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(test_identity: id, results: results)
      expect { record.duration_variance }.not_to raise_error
    end

    it "handles nil duration_ms gracefully" do
      id = make_identity
      results = [
        make_result(identity: id, status: :passed, run_id: "run-1",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP, duration_ms: nil),
        make_result(identity: id, status: :failed, run_id: "run-2",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600, duration_ms: nil)
      ]
      record = Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(test_identity: id, results: results)
      expect(record.duration_variance).to eq(0.0)
    end

    it "handles empty error_message gracefully" do
      id = make_identity
      results = flaky_results(identity: id, pass_count: 3, fail_count: 2)
      record = Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(test_identity: id, results: results)
      expect { analyzer.analyze([record]) }.not_to raise_error
    end

    it "handles all-skipped results in detection" do
      id = make_identity
      results = 5.times.map do |i|
        make_result(identity: id, status: :skipped, run_id: "run-#{i + 1}",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
      end
      records = detector.detect(results)
      expect(records).to be_empty
    end
  end

  describe "adversarial filenames" do
    it "handles path traversal-like file names safely" do
      id = make_identity(file_path: "../../../etc/passwd")
      results = flaky_results(identity: id)
      expect { detector.detect(results) }.not_to raise_error
    end

    it "handles very long file paths" do
      long_path = "spec/#{"a" * 500}_spec.rb"
      id = make_identity(file_path: long_path)
      results = flaky_results(identity: id)
      expect { detector.detect(results) }.not_to raise_error
    end

    it "handles unicode in test names" do
      id = make_identity(test_name: "validates UTF-8 input: こんにちは")
      results = flaky_results(identity: id)
      expect { detector.detect(results) }.not_to raise_error
    end
  end

  describe "History store under pressure" do
    let(:store) { Wild::Analyzers::TestFlakes::History::Store.new(max_entries: 5) }

    it "does not grow beyond max_entries" do
      10.times do |i|
        id = make_identity(test_name: "test_#{i}")
        record = flake_record_with(identity: id)
        store.record(record)
      end
      expect(store.size).to be <= 5
    end
  end

  # The old gem's Configuration class had a freeze!/frozen? lifecycle. Wild's
  # typed Struct dropped it (no-freeze configuration design). The freeze spec
  # is deleted rather than rewritten — F3 (no vanity tests of absent behavior).
end

# rubocop:enable RSpec/DescribeClass, Layout/LineLength
