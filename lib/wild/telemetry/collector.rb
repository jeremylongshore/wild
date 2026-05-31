# frozen_string_literal: true

# Wild::Telemetry::Collector — Tier 1 per ADR-0003. Session-telemetry event
# collection: receives events, validates against a schema, filters for privacy,
# stores (memory or json-lines), enforces retention, and exports records.
#
# Reads its policy from Wild.config.telemetry.collector. Code moved from the
# old wild-session-telemetry gem in Role 5 PR-8 (first of three Telemetry
# sub-namespace moves; Pipeline + Analysis follow).
#
# Deferred behavior changes tracked under wild-rvv.5's children:
#   - F7 boundary normalization (wild-rvv.5.1)
#   - F8 decomplect identity/value/time (wild-rvv.5.2)
#   - MIN-Kleppmann append-only-log fsync decision (wild-rvv.5.3)
#   - F6 export wire-or-delete audit (wild-rvv.5.4)

# Schema
require "wild/telemetry/collector/schema/event_envelope"
require "wild/telemetry/collector/schema/validator"

# Store
require "wild/telemetry/collector/store/base"
require "wild/telemetry/collector/store/memory_store"
require "wild/telemetry/collector/store/json_lines_store"
require "wild/telemetry/collector/store/retention_manager"
require "wild/telemetry/collector/store/storage_monitor"

# Privacy
require "wild/telemetry/collector/privacy/filter"

# Collector (event intake)
require "wild/telemetry/collector/collector/event_receiver"

# Export
require "wild/telemetry/collector/export/record_builder"
require "wild/telemetry/collector/export/exporter"

# Aggregation
require "wild/telemetry/collector/aggregation/engine"
require "wild/telemetry/collector/aggregation/pattern_detector"
