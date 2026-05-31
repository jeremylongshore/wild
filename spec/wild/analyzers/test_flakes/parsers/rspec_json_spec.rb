# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Parsers::RspecJson do
  subject(:parser) { described_class.new }

  describe "#parse" do
    context "with valid RSpec JSON" do
      let(:input) { rspec_json_string }

      it "returns an array of TestResult objects" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
      end

      it "parses the correct number of examples" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.size).to eq(3)
      end

      it "maps passed status correctly" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        passed = results.select(&:passed?)
        expect(passed.size).to be >= 1
      end

      it "maps failed status correctly" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        failed = results.select(&:failed?)
        expect(failed.size).to be >= 1
      end

      it "captures error messages for failures" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        failed = results.find(&:failed?)
        expect(failed.error_message).to include("expected true but got false")
      end

      it "captures duration_ms" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.duration_ms).to be_a(Numeric)
      end
    end

    context "with pending status" do
      let(:input) do
        rspec_json_string(examples: [
                            {
                              "id" => "./spec/foo_spec.rb[1:1]",
                              "description" => "does something",
                              "full_description" => "Foo does something",
                              "status" => "pending",
                              "file_path" => "./spec/foo_spec.rb",
                              "line_number" => 5
                            }
                          ])
      end

      it "maps pending status to :pending" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.status).to eq(:pending)
      end
    end

    context "when using class method" do
      it "works as a class method" do
        results = described_class.parse(
          rspec_json_string,
          run_id: "run-001",
          timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP
        )
        expect(results).to be_an(Array)
      end
    end

    context "with empty input" do
      it "raises ParseError" do
        expect { parser.parse("") }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with invalid JSON" do
      it "raises ParseError" do
        expect { parser.parse("{ not valid json") }
          .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with JSON missing examples key" do
      it "raises ParseError" do
        expect { parser.parse('{"summary": {}}') }
          .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with examples that is not an array" do
      it "raises ParseError" do
        expect { parser.parse('{"examples": "bad"}') }
          .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end
  end
end
