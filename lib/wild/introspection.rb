# frozen_string_literal: true

# Wild::Introspection — Tier 4 per ADR-0003. Safe, governed, read-only Rails
# production introspection for AI agents via MCP: schema inspection, record
# lookup, filtered queries — every call policy-enforced, audited, and bounded.
#
# Depends on Wild::Hooks (Tier 1) and Wild::CapabilityGate (Tier 3) per the
# dependency graph. Code moved from the old wild-rails-safe-introspection-mcp
# gem in Role 5 PR-11.
#
# Configuration note (wild-rvv.u16): this namespace keeps its rich
# `Wild::Introspection::Configuration` policy-loader object (reads
# access_policy.yml, resolves per-model blocked columns) and the module-level
# `Wild::Introspection.configuration` accessor (behavior-preserving).
# `Wild.config.introspection.access_policy_path` / `blocked_resources_path`
# (the central typed struct) are wired into this loader by
# #bridge_configuration!, called from Wild::Engine's config.after_initialize
# hook at boot (f-l09-2).
#
# MCP transport wiring (server/, bin/wild-mcp-introspection) is Role 9 territory;
# the server code is moved here verbatim but not yet refactored to consume the
# Wild::Hooks::McpServer substrate.

require "wild/introspection/configuration"

require "wild/introspection/adapter/write_prevention"
require "wild/introspection/adapter/model_resolver"
require "wild/introspection/adapter/model_reflector"
require "wild/introspection/adapter/schema_inspector"
require "wild/introspection/adapter/connection_manager"
require "wild/introspection/adapter/record_lookup"
require "wild/introspection/adapter/filtered_lookup"

require "wild/introspection/guard/column_resolver"
require "wild/introspection/guard/result_filter"

require "wild/introspection/audit/audit_record"
require "wild/introspection/audit/parameter_sanitizer"
require "wild/introspection/audit/audit_logger"
require "wild/introspection/audit/recorder"

require "wild/introspection/identity/request_context"
require "wild/introspection/identity/identity_resolver"
require "wild/introspection/identity/capability_gate"

require "wild/introspection/guard/query_guard"

require "wild/introspection/server/tool_handler"
require "wild/introspection/server/tools/inspect_model_schema"
require "wild/introspection/server/tools/lookup_record_by_id"
require "wild/introspection/server/tools/find_records_by_filter"
require "wild/introspection/server/server_factory"

module Wild
  module Introspection
    class << self
      # Configure the introspection policy loader. Yields the rich
      # Wild::Introspection::Configuration object and calls load! to read the
      # YAML policy files. (Distinct from the central Wild.config.introspection
      # typed struct: see #bridge_configuration! for the engine-boot wiring.)
      def configure
        yield(configuration)
        configuration.load!
      end

      # Memoized policy-loader configuration.
      def configuration
        @configuration ||= Configuration.new
      end

      # Reset the memoized configuration. Test-only.
      # @api private
      def reset!
        @configuration = nil
      end

      # Bridges Wild.config.introspection (the central typed struct consumers
      # set via `Wild.configure { |c| c.introspection.access_policy_path =
      # ... }`) into #configuration (the rich policy-loader object the
      # introspection runtime actually queries via #model_allowed?/
      # #resolve_model). Without this, setting the central struct had no
      # effect: the runtime loader is a separate, never-synced singleton, and
      # every lookup hit ModelNotAllowedError regardless of configuration
      # (f-l09-2).
      #
      # No-ops when the central access_policy_path is unset (an app that
      # never touches Wild.config.introspection is not required to configure
      # introspection at all). Once set, copies access_policy_path and
      # blocked_resources_path across and calls #configuration.load!, which
      # raises Wild::Introspection::ConfigError (unchanged, pre-existing
      # behavior) if either path is missing or unreadable: e.g. only
      # access_policy_path was set and blocked_resources_path was not.
      #
      # Called once by Wild::Engine's config.after_initialize hook at boot;
      # safe to call again (re-reads Wild.config.introspection fresh each
      # time).
      def bridge_configuration!
        central = Wild.config.introspection
        return if central.access_policy_path.nil?

        configuration.access_policy_path = central.access_policy_path
        configuration.blocked_resources_path = central.blocked_resources_path
        configuration.load!
      end
    end
  end
end
