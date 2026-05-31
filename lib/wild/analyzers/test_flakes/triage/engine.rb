# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Triage
        class Engine
          def initialize(scorer: nil, remediation: nil, history_store: nil)
            @scorer = scorer || SeverityScorer.new
            @remediation = remediation || Remediation.new
            @history_store = history_store
          end

          def triage(flake_records)
            raise ArgumentError, "flake_records must be an Array" unless flake_records.is_a?(Array)

            entries = flake_records.filter_map { |record| build_entry(record) }
            entries.sort_by { |e| -e.severity_score }
          end

          private

          def build_entry(record)
            trend = fetch_trend(record)
            score = @scorer.score(record, trend: trend)
            severity = @scorer.severity_from_score(score)
            suggestions = @remediation.all_suggestions_for(record.root_causes)

            Models::TriageEntry.new(
              flake_record: record,
              severity: severity,
              severity_score: score,
              remediations: suggestions,
              trend: trend
            )
          end

          def fetch_trend(record)
            return :stable unless @history_store

            @history_store.trend_for(record.test_identity) || :stable
          end
        end
      end
    end
  end
end
