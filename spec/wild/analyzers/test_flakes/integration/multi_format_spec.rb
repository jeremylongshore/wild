# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Multi-format parsing integration" do
  let(:detector) { Wild::Analyzers::TestFlakes::Detection::FlakeDetector.new(minimum_runs: 2) }
  let(:run_id) { "run-multi-001" }
  let(:timestamp) { Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP }

  def parse_rspec(examples:)
    Wild::Analyzers::TestFlakes::Parsers::RspecJson.parse(
      rspec_json_string(examples: examples),
      run_id: run_id,
      timestamp: timestamp
    )
  end

  def parse_junit(cases:)
    Wild::Analyzers::TestFlakes::Parsers::JunitXml.parse(
      junit_xml_string(test_cases: cases),
      run_id: run_id,
      timestamp: timestamp
    )
  end

  def parse_minitest(tests:)
    Wild::Analyzers::TestFlakes::Parsers::MinitestJson.parse(
      minitest_json_string(tests: tests),
      run_id: run_id,
      timestamp: timestamp
    )
  end

  describe "parsing different formats and combining results" do
    it "parses RSpec JSON results successfully" do
      results = parse_rspec(examples: default_rspec_examples)
      expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
    end

    it "parses JUnit XML results successfully" do
      results = parse_junit(cases: default_junit_cases)
      expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
    end

    it "parses minitest JSON results successfully" do
      results = parse_minitest(tests: default_minitest_tests)
      expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
    end

    it "combined results from multiple formats can be fed to detector" do
      rspec_results = parse_rspec(examples: default_rspec_examples)
      junit_results = parse_junit(cases: default_junit_cases)
      minitest_results = parse_minitest(tests: default_minitest_tests)

      all_results = rspec_results + junit_results + minitest_results
      expect { detector.detect(all_results) }.not_to raise_error
    end
  end

  describe "simulating multi-run flake detection across formats" do
    let(:passing_example) do
      [{ "full_description" => "UserModel is valid", "status" => "passed",
         "file_path" => "./spec/models/user_spec.rb", "run_time" => 0.01 }]
    end

    let(:failing_example) do
      [{ "full_description" => "UserModel is valid", "status" => "failed",
         "file_path" => "./spec/models/user_spec.rb", "run_time" => 0.01,
         "exception" => { "message" => "expected true got false" } }]
    end

    it "detects flake from two RSpec runs with different outcomes" do
      run1 = Wild::Analyzers::TestFlakes::Parsers::RspecJson.parse(
        rspec_json_string(examples: passing_example),
        run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP
      )
      run2 = Wild::Analyzers::TestFlakes::Parsers::RspecJson.parse(
        rspec_json_string(examples: failing_example),
        run_id: "run-002", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + 3600
      )
      records = detector.detect(run1 + run2)
      expect(records.size).to eq(1)
      expect(records.first.flake_rate).to eq(0.5)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
