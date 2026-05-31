# frozen_string_literal: true

# Wild::Analyzers::Permission — Tier 2 per ADR-0003. Static analysis of
# capability/grant configurations: coverage, consistency, risk, prerequisite
# depth, orphan + shadow detection, wildcard matching.
#
# Reads its policy from Wild.config.analyzers.permission. Code moved from the
# old wild-permission-analyzer gem in Role 5 PR-6.
#
# NOTE: the Fowler detect_cycle false-positive fix and the F3 vanity-test
# replacement are deferred behavior changes tracked under wild-rvv.7's
# children — this PR is the structure-only move.

# Models
require "wild/analyzers/permission/models/capability"
require "wild/analyzers/permission/models/grant"
require "wild/analyzers/permission/models/finding"
require "wild/analyzers/permission/models/coverage_report"
require "wild/analyzers/permission/models/audit_report"

# Loaders
require "wild/analyzers/permission/loaders/capabilities_loader"
require "wild/analyzers/permission/loaders/grants_loader"

# Analyzers
require "wild/analyzers/permission/analyzers/wildcard_matcher"
require "wild/analyzers/permission/analyzers/consistency_analyzer"
require "wild/analyzers/permission/analyzers/risk_analyzer"
require "wild/analyzers/permission/analyzers/prerequisite_analyzer"
require "wild/analyzers/permission/analyzers/coverage_analyzer"
require "wild/analyzers/permission/analyzers/orphan_analyzer"
require "wild/analyzers/permission/analyzers/shadow_analyzer"

# Report
require "wild/analyzers/permission/report/builder"

# Export — flagged for F6 wire-or-delete audit under wild-rvv.5.4; required
# here to preserve test coverage during the structure move.
require "wild/analyzers/permission/export/json_exporter"
require "wild/analyzers/permission/export/markdown_exporter"

module Wild
  module Analyzers
    module Permission
      # Convenience: load both files and run the full audit. Paths fall back
      # to Wild.config.analyzers.permission.{capabilities_path,grants_path}.
      def self.audit(capabilities_path: nil, grants_path: nil)
        cfg = Wild.config.analyzers.permission
        cap_path = capabilities_path || cfg.capabilities_path
        gr_path  = grants_path || cfg.grants_path

        raise Wild::ConfigurationError, "capabilities_path must be set" if cap_path.nil?
        raise Wild::ConfigurationError, "grants_path must be set" if gr_path.nil?

        capabilities = Loaders::CapabilitiesLoader.load(cap_path)
        grants       = Loaders::GrantsLoader.load(gr_path)
        Report::Builder.new(capabilities, grants).build
      end
    end
  end
end
