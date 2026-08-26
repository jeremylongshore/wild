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
# Concrete adapters (finding f-l10-2): these were previously never required,
# so `Wild::AdminTools::Executor::Adapters::RailsCacheAdapter` etc. raised
# NameError for any consumer following the documented
# `config.admin_tools.cache_adapter = Rails.cache`-style wiring, and the 291
# LOC were invisible to coverage. None of the three requires the underlying
# gem (sidekiq/flipper) at load time -- each adapter lazily `require`s its
# gem only inside the methods that need it and raises AdapterError on
# LoadError, so the gem keeps loading in a host app that has neither gem
# installed.
require "wild/admin_tools/executor/adapters/rails_cache_adapter"
require "wild/admin_tools/executor/adapters/sidekiq_adapter"
require "wild/admin_tools/executor/adapters/flipper_adapter"
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
      # Wild.config.admin_tools typed struct (bridged into this object by
      # #bridge_configuration!, wild-rvv.uku reconciliation, f-l10-3).
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

      # Bridges the central Wild.config.admin_tools typed struct into this
      # namespace's own #configuration object, which is what
      # Executor::CacheExecutor / JobExecutor / FlagExecutor actually read
      # from (wild-rvv.uku). For each of cache_adapter/job_adapter/
      # flag_adapter:
      #
      #   - a :default sentinel (the struct's own default) resolves to a
      #     concrete Executor::Adapters instance wrapping the matching
      #     backend, IF that backend is loaded (Rails.cache is always
      #     available in a booted Rails app; Sidekiq/Flipper are optional
      #     gems and only resolve when the consumer's Gemfile includes them)
      #   - any other value (nil, or an adapter the consumer configured
      #     explicitly via `Wild.configure { |c| c.admin_tools.X = ... }`) is
      #     copied through unchanged
      #
      # Finishes by calling #configuration.validate!, which raises
      # Wild::ConfigurationError naming any adapter still nil after
      # bridging (an unconfigured :default with no backend loaded, or an
      # explicit `nil` the consumer set). Called once by Wild::Engine's
      # config.after_initialize hook at boot; safe to call again (re-reads
      # Wild.config.admin_tools fresh each time, no memoized bridging state).
      #
      # Note: there is no shipped job_adapter backend for plain
      # ActiveJob::Base (ActiveJob has no generic queue-introspection API to
      # wrap): only Sidekiq. A consumer on a different queue backend, or
      # who wants admin_tools without Sidekiq/Flipper installed, must set
      # cache_adapter/job_adapter/flag_adapter explicitly.
      def bridge_configuration!
        require_concrete_adapters!
        assign_resolved_adapters!
        configuration.validate!
      end

      private

      # @api private
      def require_concrete_adapters!
        require "wild/admin_tools/executor/adapters/rails_cache_adapter"
        require "wild/admin_tools/executor/adapters/sidekiq_adapter"
        require "wild/admin_tools/executor/adapters/flipper_adapter"
      end

      # @api private
      def assign_resolved_adapters!
        central = Wild.config.admin_tools
        configuration.cache_adapter = resolve_cache_adapter(central.cache_adapter)
        configuration.job_adapter = resolve_job_adapter(central.job_adapter)
        configuration.flag_adapter = resolve_flag_adapter(central.flag_adapter)
      end

      # @api private
      def resolve_cache_adapter(central_value)
        resolve_default_adapter(:cache_adapter, central_value) do
          Executor::Adapters::RailsCacheAdapter.new if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
        end
      end

      # @api private
      def resolve_job_adapter(central_value)
        resolve_default_adapter(:job_adapter, central_value) do
          Executor::Adapters::SidekiqAdapter.new if defined?(Sidekiq)
        end
      end

      # @api private
      def resolve_flag_adapter(central_value)
        resolve_default_adapter(:flag_adapter, central_value) do
          Executor::Adapters::FlipperAdapter.new if defined?(Flipper)
        end
      end

      # @api private
      def resolve_default_adapter(setting_name, central_value)
        return central_value unless central_value == :default

        yield || raise(
          Wild::ConfigurationError,
          "Wild.config.admin_tools.#{setting_name} is :default but no backend gem is loaded to " \
          "resolve it. Set Wild.config.admin_tools.#{setting_name} explicitly in an initializer, " \
          "or add the backend gem this default expects (Sidekiq for job_adapter, Flipper for " \
          "flag_adapter) to your Gemfile."
        )
      end
    end
  end
end
