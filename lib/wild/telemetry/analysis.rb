# frozen_string_literal: true

# Wild::Telemetry::Analysis — Tier 2 per ADR-0003. Gap analysis over telemetry
# exports: ingests a JSONL export, runs denial/failure/latency/utilization/
# coverage/pattern analyzers, scores severity, ranks priority, and builds a
# gap report with recommendations.
#
# Reads its policy from Wild.config.telemetry.analysis. Code moved from the
# old wild-gap-miner gem in Role 5 PR-10 (third + final Telemetry sub-namespace
# move — completes the wild-rvv.5 epic structure).
#
# Deferred behavior changes tracked under wild-rvv.5's children (F7/F8/
# MIN-Kleppmann/F6).

# Models
require "wild/telemetry/analysis/models/telemetry_record"
require "wild/telemetry/analysis/models/export_header"
require "wild/telemetry/analysis/models/event_record"
require "wild/telemetry/analysis/models/session_summary"
require "wild/telemetry/analysis/models/tool_utilization"
require "wild/telemetry/analysis/models/outcome_distribution"
require "wild/telemetry/analysis/models/latency_stats"
require "wild/telemetry/analysis/models/pattern_record"
require "wild/telemetry/analysis/models/gap"
require "wild/telemetry/analysis/models/gap_report"

# Ingestion
require "wild/telemetry/analysis/ingestion/record_factory"
require "wild/telemetry/analysis/ingestion/export_parser"

# Analyzers
require "wild/telemetry/analysis/analyzers/base"
require "wild/telemetry/analysis/analyzers/denial_analyzer"
require "wild/telemetry/analysis/analyzers/failure_analyzer"
require "wild/telemetry/analysis/analyzers/latency_analyzer"
require "wild/telemetry/analysis/analyzers/utilization_analyzer"
require "wild/telemetry/analysis/analyzers/coverage_analyzer"
require "wild/telemetry/analysis/analyzers/pattern_analyzer"

# Scoring
require "wild/telemetry/analysis/scoring/severity_scorer"
require "wild/telemetry/analysis/scoring/priority_ranker"

# Recommendations + report
require "wild/telemetry/analysis/recommendations/engine"
require "wild/telemetry/analysis/report/builder"

# Export — flagged for F6 wire-or-delete audit under wild-rvv.5.4.
require "wild/telemetry/analysis/export/json_exporter"
require "wild/telemetry/analysis/export/markdown_exporter"

module Wild
  module Telemetry
    module Analysis
      # Convenience: parse a telemetry-export JSONL file and build a gap report.
      def self.analyze(path, config: Wild.config.telemetry.analysis)
        parser = Ingestion::ExportParser.new(config: config)
        parsed = parser.parse_file(path)
        builder_records = parsed[:records].merge(header: parsed[:header])
        Report::Builder.new(records: builder_records, config: config).build
      end
    end
  end
end
