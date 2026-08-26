# frozen_string_literal: true

# Wild::CapabilityGate — Tier 3 per ADR-0003. Governed access control for
# privileged AI-agent capabilities. Depends on Wild::Hooks (Tier 1, audit
# substrate). Consumed by Wild::Introspection and Wild::AdminTools (both
# Tier 4) once Role 7 wires Introspection::Identity::CapabilityGate to this
# namespace (as of 2026-08-25 nothing in lib/ calls this module: review
# wave finding f-l08-12). Does NOT depend on Wild::Analyzers::Permission:
# see lib/wild/capability_gate/package.yml for the F4 vacuous-satisfaction
# note (no wildcard-name matching happens in this namespace at all).
#
# Code moved from the old wild-capability-gate gem in Role 5 PR-4
# (closes wild-rvv.4 epic base move; F2 audit-blind behavior fix is
# Role 6's wild-rvv.4.1).

require_relative "capability_gate/prerequisite"
require_relative "capability_gate/capability"
require_relative "capability_gate/grant"
require_relative "capability_gate/evaluation_result"
require_relative "capability_gate/registry"
require_relative "capability_gate/prerequisites/check_result"
require_relative "capability_gate/prerequisites/file_exists_checker"
require_relative "capability_gate/prerequisites/config_value_checker"
require_relative "capability_gate/prerequisites/checker"
require_relative "capability_gate/evaluator"
require_relative "capability_gate/audit/event"
require_relative "capability_gate/audit/json_lines_writer"
require_relative "capability_gate/audit/schema_validator"
require_relative "capability_gate/session"
require_relative "capability_gate/session/store"
require_relative "capability_gate/gate"

module Wild
  module CapabilityGate
    # Convenience constructor — delegates to Gate.new.
    # Usage: gate = Wild::CapabilityGate.new(config_path: "config/capability_gate")
    def self.new(**)
      Gate.new(**)
    end
  end
end
