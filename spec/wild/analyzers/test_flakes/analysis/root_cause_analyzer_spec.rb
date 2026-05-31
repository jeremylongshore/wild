# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Analysis::RootCauseAnalyzer do
  subject(:analyzer) { described_class.new }

  describe "#analyze" do
    context "with high timing variance records" do
      let(:identity) { make_identity }
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: identity,
          results: results_with_high_variance(identity: identity)
        )
      end

      it "assigns root causes" do
        analyzed = analyzer.analyze([record])
        expect(analyzed.first.root_causes).not_to be_empty
      end

      it "returns FlakeRecord objects" do
        analyzed = analyzer.analyze([record])
        expect(analyzed).to all(be_a(Wild::Analyzers::TestFlakes::Models::FlakeRecord))
      end
    end

    context "with external dependency signals" do
      let(:identity) { make_identity }
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: identity,
          results: results_with_external_errors(identity: identity)
        )
      end

      it "identifies external_dependency as a root cause" do
        analyzed = analyzer.analyze([record])
        categories = analyzed.first.root_causes.map(&:category)
        expect(categories).to include(:external_dependency)
      end
    end

    context "with timezone signals" do
      let(:identity) { make_identity }
      let(:record) do
        Wild::Analyzers::TestFlakes::Models::FlakeRecord.new(
          test_identity: identity,
          results: results_with_timezone_errors(identity: identity)
        )
      end

      it "identifies timezone_locale as a root cause" do
        analyzed = analyzer.analyze([record])
        categories = analyzed.first.root_causes.map(&:category)
        expect(categories).to include(:timezone_locale)
      end
    end

    context "with no discernible signals" do
      let(:record) { flake_record_with }

      it "assigns unknown root cause when no signals match" do
        analyzed = analyzer.analyze([record])
        expect(analyzed.first.root_causes).not_to be_empty
      end
    end

    context "with multiple records in same file" do
      let(:records) { multiple_flake_records(count: 3, base_file: "spec/shared") }

      it "processes all records" do
        analyzed = analyzer.analyze(records)
        expect(analyzed.size).to eq(3)
      end
    end

    context "with invalid input" do
      it "raises ArgumentError" do
        expect { analyzer.analyze("bad") }.to raise_error(ArgumentError)
      end
    end

    context "with empty input" do
      it "returns empty array" do
        expect(analyzer.analyze([])).to eq([])
      end
    end
  end
end
