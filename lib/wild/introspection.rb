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
# `Wild::Introspection.configuration` accessor — behavior-preserving. Wiring
# `Wild.config.introspection.access_policy_path` (the central typed struct)
# into this loader at engine boot is a deferred Role 6/8 task.
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
      # typed struct — see wild-rvv.u16 for the planned engine-boot wiring.)
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
    end
  end
end
