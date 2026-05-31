# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass

RSpec.describe "Malformed input handling" do
  let(:rspec_parser) { Wild::Analyzers::TestFlakes::Parsers::RspecJson.new }
  let(:junit_parser) { Wild::Analyzers::TestFlakes::Parsers::JunitXml.new }
  let(:minitest_parser) { Wild::Analyzers::TestFlakes::Parsers::MinitestJson.new }
  let(:opts) { { run_id: "run-001", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP } }

  describe "RSpec JSON parser" do
    it "raises ParseError for nil input" do
      expect { rspec_parser.parse(nil, **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for empty string" do
      expect { rspec_parser.parse("", **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for whitespace only" do
      expect { rspec_parser.parse("   ", **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for truncated JSON" do
      expect { rspec_parser.parse('{"examples": [{"id": "foo"', **opts) }
        .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for JSON array at root" do
      expect { rspec_parser.parse("[]", **opts) }
        .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for JSON object without examples" do
      expect { rspec_parser.parse('{"summary": {}}', **opts) }
        .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "skips non-hash example entries gracefully" do
      json = JSON.generate({ "examples" => ["string_entry", nil, 42, { "status" => "passed",
                                                                       "file_path" => "./spec/foo.rb",
                                                                       "full_description" => "Foo bar" }] })
      results = rspec_parser.parse(json, **opts)
      expect(results).to be_an(Array)
    end
  end

  describe "JUnit XML parser" do
    it "raises ParseError for nil input" do
      expect { junit_parser.parse(nil, **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for empty string" do
      expect { junit_parser.parse("", **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for XML with wrong root element" do
      xml = "<html><body>not junit</body></html>"
      expect { junit_parser.parse(xml, **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for completely malformed XML" do
      expect { junit_parser.parse("<<<<", **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "handles empty testsuite gracefully" do
      xml = '<testsuite name="empty"></testsuite>'
      results = junit_parser.parse(xml, **opts)
      expect(results).to eq([])
    end
  end

  describe "Minitest JSON parser" do
    it "raises ParseError for nil input" do
      expect { minitest_parser.parse(nil, **opts) }.to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for JSON without tests or results key" do
      expect { minitest_parser.parse('{"count": 5}', **opts) }
        .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "raises ParseError for non-JSON input" do
      expect { minitest_parser.parse("Run options: --seed 12345", **opts) }
        .to raise_error(Wild::Analyzers::TestFlakes::ParseError)
    end

    it "skips non-hash test entries" do
      json = JSON.generate({ "tests" => [nil, "bad", { "name" => "test_foo",
                                                       "class" => "FooTest", "result" => "pass" }] })
      results = minitest_parser.parse(json, **opts)
      expect(results).to be_an(Array)
    end
  end
end

# rubocop:enable RSpec/DescribeClass
