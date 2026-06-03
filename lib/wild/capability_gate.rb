# frozen_string_literal: true

# Wild::CapabilityGate — Tier 3 per ADR-0003. Governed access control for
# privileged AI-agent capabilities. Depends on Wild::Hooks (Tier 1, audit
# substrate) and Wild::Analyzers::Permission (Tier 2). Consumed by
# Wild::Introspection and Wild::AdminTools (both Tier 4).
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
