# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers, Layout/LineLength

RSpec.describe "Full pipeline integration" do
  let(:detector) { Wild::Analyzers::TestFlakes::Detection::FlakeDetector.new(minimum_runs: 3) }
  let(:analyzer) { Wild::Analyzers::TestFlakes::Analysis::RootCauseAnalyzer.new }
  let(:engine) { Wild::Analyzers::TestFlakes::Triage::Engine.new }
  let(:json_exporter) { Wild::Analyzers::TestFlakes::Export::JsonExporter.new }
  let(:markdown_exporter) { Wild::Analyzers::TestFlakes::Export::MarkdownExporter.new }
  let(:summary_exporter) { Wild::Analyzers::TestFlakes::Export::SummaryExporter.new }

  context "with flaky test results" do
    let(:user_profile_identity) { make_identity(test_name: "loads user profile", context: "UserController") }
    let(:email_identity) { make_identity(test_name: "sends confirmation email", context: "MailerJob") }
    let(:stable_identity) { make_identity(test_name: "returns 200 OK", context: "HealthCheck") }

    let(:results) do
      flaky1 = flaky_results(identity: user_profile_identity, pass_count: 4, fail_count: 2)
      flaky2 = results_with_external_errors(identity: email_identity)
      stable = 5.times.map do |i|
        make_result(identity: stable_identity, status: :passed, run_id: "run-#{i + 1}",
                    timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
      end
      flaky1 + flaky2 + stable
    end

    it "completes the full pipeline without errors" do
      flakes = detector.detect(results)
      analyzed = analyzer.analyze(flakes, all_results: results)
      entries = engine.triage(analyzed)

      expect(entries).not_to be_empty
      expect(entries).to all(be_a(Wild::Analyzers::TestFlakes::Models::TriageEntry))
    end

    it "identifies the flaky tests but not the stable test" do
      flakes = detector.detect(results)
      test_names = flakes.map { |f| f.test_identity.test_name }

      expect(test_names).to include("loads user profile")
      expect(test_names).not_to include("returns 200 OK")
    end

    it "produces valid JSON output" do
      flakes = detector.detect(results)
      analyzed = analyzer.analyze(flakes, all_results: results)
      entries = engine.triage(analyzed)
      json_output = json_exporter.export(entries)

      parsed = JSON.parse(json_output)
      expect(parsed["summary"]["total"]).to be >= 1
    end

    it "produces non-empty markdown output" do
      flakes = detector.detect(results)
      analyzed = analyzer.analyze(flakes, all_results: results)
      entries = engine.triage(analyzed)
      md_output = markdown_exporter.export(entries)

      expect(md_output).to include("## Summary")
      expect(md_output).to include("## Flaky Tests")
    end

    it "produces summary output" do
      flakes = detector.detect(results)
      analyzed = analyzer.analyze(flakes, all_results: results)
      entries = engine.triage(analyzed)
      summary = summary_exporter.export(entries)

      expect(summary).to include("FLAKE REPORT")
    end

    it "assigns root causes to detected flakes" do
      flakes = detector.detect(results)
      analyzed = analyzer.analyze(flakes, all_results: results)

      analyzed.each do |record|
        expect(record.root_causes).not_to be_empty
      end
    end
  end

  context "with no flaky results" do
    let(:results) do
      5.times.flat_map do |i|
        [
          make_result(identity: make_identity(test_name: "test_a"), status: :passed,
                      run_id: "run-#{i + 1}", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600)),
          make_result(identity: make_identity(test_name: "test_b"), status: :passed,
                      run_id: "run-#{i + 1}", timestamp: Wild::Analyzers::TestFlakes::TestSupport::Fixtures::BASE_TIMESTAMP + (i * 3600))
        ]
      end
    end

    it "produces no triage entries" do
      flakes = detector.detect(results)
      entries = engine.triage(flakes)
      expect(entries).to be_empty
    end

    it "exports cleanly with empty entries" do
      entries = []
      expect(json_exporter.export(entries)).to include('"total":0')
      expect(summary_exporter.export(entries)).to include("No flaky tests detected")
    end
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers, Layout/LineLength
