# frozen_string_literal: true

# Wild::Analyzers::TestFlakes — Tier 2 per ADR-0003. Test flake detection,
# root-cause analysis, and triage: parses rspec/junit/minitest reports,
# detects flakes by pass/fail history, scores severity, tracks trends.
#
# Reads its policy from Wild.config.analyzers.test_flakes. Code moved from the
# old wild-test-flake-forensics gem in Role 5 PR-7.
#
# NOTE: the F3 vanity-test replacement (golden-corpus classifier tests) is a
# deferred behavior change tracked under wild-rvv.7.1 — this PR is the
# structure-only move.

# Models
require "wild/analyzers/test_flakes/models/test_identity"
require "wild/analyzers/test_flakes/models/test_result"
require "wild/analyzers/test_flakes/models/root_cause"
require "wild/analyzers/test_flakes/models/flake_record"
require "wild/analyzers/test_flakes/models/triage_entry"

# Parsers
require "wild/analyzers/test_flakes/parsers/base"
require "wild/analyzers/test_flakes/parsers/rspec_json"
require "wild/analyzers/test_flakes/parsers/junit_xml"
require "wild/analyzers/test_flakes/parsers/minitest_json"

# Detection
require "wild/analyzers/test_flakes/detection/comparator"
require "wild/analyzers/test_flakes/detection/flake_detector"

# Analysis
require "wild/analyzers/test_flakes/analysis/signal_extractors"
require "wild/analyzers/test_flakes/analysis/root_cause_analyzer"

# Triage
require "wild/analyzers/test_flakes/triage/severity_scorer"
require "wild/analyzers/test_flakes/triage/remediation"
require "wild/analyzers/test_flakes/triage/engine"

# History
require "wild/analyzers/test_flakes/history/trend_analyzer"
require "wild/analyzers/test_flakes/history/store"

# Export — flagged for F6 wire-or-delete audit under wild-rvv.5.4 (Beck named
# 2 of these 3 exporters as half-published). Required here to preserve test
# coverage during the structure move; the wire-or-delete decision is deferred.
require "wild/analyzers/test_flakes/export/json_exporter"
require "wild/analyzers/test_flakes/export/markdown_exporter"
require "wild/analyzers/test_flakes/export/summary_exporter"
