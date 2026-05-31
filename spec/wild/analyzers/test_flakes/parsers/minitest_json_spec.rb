# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Parsers::MinitestJson do
  subject(:parser) { described_class.new }

  describe "#parse" do
    context 'with valid minitest JSON using "tests" key' do
      let(:input) { minitest_json_string }

      it "returns TestResult objects" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
      end

      it "parses all tests" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.size).to eq(3)
      end

      it "maps pass to :passed" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.select(&:passed?).size).to be >= 1
      end

      it "maps fail to :failed with error" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        failed = results.find(&:failed?)
        expect(failed).not_to be_nil
      end
    end

    context 'with "results" key instead of "tests"' do
      let(:input) do
        JSON.generate({
                        "results" => [
                          { "name" => "test_foo", "class" => "FooTest", "result" => "pass", "time" => 0.05 }
                        ]
                      })
      end

      it "parses successfully" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.size).to eq(1)
      end
    end

    context "with skip status" do
      let(:input) do
        JSON.generate({
                        "tests" => [
                          { "name" => "test_skip", "class" => "FooTest", "result" => "skip" }
                        ]
                      })
      end

      it "maps to :skipped" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.status).to eq(:skipped)
      end
    end

    context "with error status" do
      let(:input) do
        JSON.generate({
                        "tests" => [
                          { "name" => "test_err", "class" => "FooTest", "result" => "error", "error" => "boom" }
                        ]
                      })
      end

      it "maps to :errored" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.status).to eq(:errored)
      end
    end

    context "with empty input" do
      it "raises ParseError" do
        expect { parser.parse("") }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with invalid JSON" do
      it "raises ParseError" do
        expect { parser.parse("not json") }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with missing tests key" do
      it "raises ParseError" do
        expect { parser.parse('{"summary": {}}') }
          .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end
  end
end
