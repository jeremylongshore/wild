# frozen_string_literal: true

# Wild::Hooks — Tier 1 substrate per ADR-0003. Centralized hook lifecycle
# management: registration, execution, auditing, and health monitoring for
# agent workflow extension points.
#
# Wild::CapabilityGate, Wild::Introspection, Wild::AdminTools, and the
# Telemetry/Analyzers/Skillops namespaces all depend on this substrate
# (per the dependency graph in 000-docs/adr/ADR-0003-namespace-dependency-graph.md).
#
# Code moved from the old wild-hook-ops gem in Role 5 PR-1
# (closes wild-rvv.6 parent epic; 6.1 + 6.2 substrate-extraction children
# remain open for follow-up PRs that pull MCP server scaffold + audit-logging
# patterns from introspection + admin_tools into this namespace).

# Models — immutable descriptors and result records.
require "wild/hooks/models/hook_definition"
require "wild/hooks/models/hook_handler"
require "wild/hooks/models/hook_result"
require "wild/hooks/models/hook_event"

# Registry — thread-safe stores for hook definitions and handlers.
require "wild/hooks/registry/definition_store"
require "wild/hooks/registry/handler_store"
require "wild/hooks/registry/hook_registry"

# Execution — runner, timeout guard, error isolation.
require "wild/hooks/execution/timeout_guard"
require "wild/hooks/execution/error_isolator"
require "wild/hooks/execution/runner"

# Lifecycle — versioning and definition lifecycle management.
require "wild/hooks/lifecycle/version_tracker"
require "wild/hooks/lifecycle/manager"

# Health — per-handler metrics and reporting.
require "wild/hooks/health/monitor"
require "wild/hooks/health/reporter"

# Audit — ring-buffer trail + event logger (from wild-hook-ops) plus
# shared sanitizer + timer substrate consumed by introspection,
# admin_tools, and capability_gate emitters.
require "wild/hooks/audit/trail"
require "wild/hooks/audit/logger"
require "wild/hooks/audit/sanitizer"
require "wild/hooks/audit/timer"

# MCP server — transport-layer substrate consumed by Wild::Introspection +
# Wild::AdminTools. Pulls in the `mcp` gem on first load (per wild.gemspec).
require "wild/hooks/mcp_server"
