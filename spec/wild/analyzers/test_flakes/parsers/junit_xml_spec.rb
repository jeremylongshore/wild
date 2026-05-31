# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Parsers::JunitXml do
  subject(:parser) { described_class.new }

  describe "#parse" do
    context "with valid JUnit XML" do
      let(:input) { junit_xml_string }

      it "returns TestResult objects" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results).to all(be_a(Wild::Analyzers::TestFlakes::Models::TestResult))
      end

      it "parses all test cases" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.size).to eq(3)
      end

      it "parses passing tests" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.select(&:passed?).size).to be >= 1
      end

      it "parses failing tests with error message" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        failed = results.find(&:failed?)
        expect(failed).not_to be_nil
        expect(failed.error_message).not_to be_nil
      end

      it "parses duration_ms" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.duration_ms).to be_a(Numeric)
      end
    end

    context "with testsuites root element" do
      let(:input) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuites>
            <testsuite name="Suite1">
              <testcase classname="Foo" name="test_it" time="0.1"/>
            </testsuite>
          </testsuites>
        XML
      end

      it "parses successfully" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.size).to eq(1)
      end
    end

    context "with skipped tests" do
      let(:input) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <testsuite name="Suite">
            <testcase classname="Foo" name="skipped_test"><skipped/></testcase>
          </testsuite>
        XML
      end

      it "maps to :skipped status" do
        results = parser.parse(input, run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP)
        expect(results.first.status).to eq(:skipped)
      end
    end

    context "with empty input" do
      it "raises ParseError" do
        expect { parser.parse("") }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with invalid XML" do
      it "raises ParseError" do
        expect { parser.parse("<not valid xml") }
          .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end

    context "with wrong root element" do
      it "raises ParseError" do
        xml = '<?xml version="1.0"?><report><testcase name="x"/></report>'
        expect { parser.parse(xml) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
      end
    end
  end
end
