# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Report
        # Orchestrates all analyzers, scoring, and recommendation enrichment
        # to produce a GapReport from parsed telemetry records.
        class Builder
          ANALYZERS = [
            Analyzers::DenialAnalyzer,
            Analyzers::FailureAnalyzer,
            Analyzers::LatencyAnalyzer,
            Analyzers::UtilizationAnalyzer,
            Analyzers::CoverageAnalyzer,
            Analyzers::PatternAnalyzer
          ].freeze

          attr_reader :records, :config

          def initialize(records:, config: Wild.config.telemetry.analysis)
            @records = records
            @config = config
          end

          def build
            header = records[:header]
            typed_records = records.except(:header)

            raw_gaps = run_analyzers(typed_records)
            scored_gaps = score(raw_gaps)
            enriched_gaps = enrich(scored_gaps)

            Models::GapReport.new(header: header, gaps: enriched_gaps)
          end

          private

          def run_analyzers(typed_records)
            ANALYZERS.flat_map do |analyzer_class|
              analyzer_class.new(config: config).analyze(typed_records)
            end
          end

          def score(gaps)
            Scoring::SeverityScorer.new(config: config).score_all(gaps)
          end

          def enrich(gaps)
            Recommendations::Engine.new.enrich(gaps)
          end
        end
      end
    end
  end
end
