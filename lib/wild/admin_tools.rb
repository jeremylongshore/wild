# frozen_string_literal: true

# Wild::AdminTools — Tier 4 per ADR-0003. Governed administrative operations
# (background jobs, cache, feature flags) for Rails apps via MCP: every action
# dry-run previewed, confirmation-gated, capability-gated, audited with
# before/after snapshots, and bounded by blast-radius caps + rate limits.
#
# Depends on Wild::Hooks (Tier 1) and Wild::CapabilityGate (Tier 3) per the
# dependency graph. Code moved from the old wild-admin-tools-mcp gem in
# Role 5 PR-12 (the final namespace move — completes the 10-namespace
# consolidation).
#
# Trust boundary: the guard chain (Guard::Pipeline#call, wrapped by
# Audit::AuditedPipeline#call and Identity::AuthenticatedPipeline#call) gates
# the PUBLIC surface reachable by an untrusted external caller (an MCP client
# via Server::ToolHandler): allowlist, param validation, rate limit,
# blast-radius, and audit, all enforced before any mutation reaches an
# executor; it is not a defense against in-process Ruby code, which already
# runs with this object's privileges and could always reach an executor or
# TwoPhaseFlow directly (security-review follow-up on f-l10-4, PR #73).
#
# Configuration note (wild-rvv.uku): this namespace keeps its
# `Wild::AdminTools::Configuration` object (cache/job/flag adapters + gate +
# policy_path + audit settings, all nil-default = dependency-injection points)
# and the module-level `Wild::AdminTools.configuration` accessor —
# behavior-preserving. Reconciling these injection points with the central
# `Wild::Configuration::AdminTools` `:default` sentinels (PR-B) — i.e. the
# "kill the DI container" adapter-defaulting at engine boot — is a deferred
# Role 8 task overlapping wild-rvv.3.1.
#
# MCP transport wiring (server/, bin/wild-mcp-admin) is Role 9 territory; the
# server code is moved here verbatim, not yet refactored to consume the
# Wild::Hooks::McpServer substrate.

require "wild/admin_tools/result"
require "wild/admin_tools/configuration"

require "wild/admin_tools/executor/adapters/job_adapter"
require "wild/admin_tools/executor/adapters/cache_adapter"
require "wild/admin_tools/executor/adapters/flag_adapter"
require "wild/admin_tools/executor/state_capture"
require "wild/admin_tools/executor/base"
require "wild/admin_tools/executor/job_executor"
require "wild/admin_tools/executor/cache_executor"
require "wild/admin_tools/executor/flag_executor"

require "wild/admin_tools/guard/policy_config"
require "wild/admin_tools/guard/action_allowlist"
require "wild/admin_tools/guard/parameter_validator"
require "wild/admin_tools/guard/blast_radius_enforcer"
require "wild/admin_tools/guard/sliding_window"
require "wild/admin_tools/guard/rate_limiter"
require "wild/admin_tools/guard/nonce_store"
require "wild/admin_tools/guard/nonce_manager"
require "wild/admin_tools/guard/two_phase_flow"
require "wild/admin_tools/guard/pipeline"

require "wild/admin_tools/audit/record"
require "wild/admin_tools/audit/parameter_sanitizer"
require "wild/admin_tools/audit/store"
require "wild/admin_tools/audit/recorder"
require "wild/admin_tools/audit/audited_pipeline"

require "wild/admin_tools/identity/session_context"
require "wild/admin_tools/identity/identity_extractor"
require "wild/admin_tools/identity/gate_client"
require "wild/admin_tools/identity/gate_health_check"
require "wild/admin_tools/identity/authenticated_pipeline"

require "wild/admin_tools/server/response_formatter"
require "wild/admin_tools/server/tool_handler"
require "wild/admin_tools/server/tools/manage_background_jobs"
require "wild/admin_tools/server/tools/manage_cache"
require "wild/admin_tools/server/tools/manage_feature_flags"
require "wild/admin_tools/server/server_factory"

module Wild
  module AdminTools
    class << self
      # The namespace-internal configuration object (adapters/gate/policy are
      # dependency-injected; nil-default). Distinct from the central
      # Wild.config.admin_tools typed struct — see wild-rvv.uku for the planned
      # engine-boot reconciliation.
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      # @api private
      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
