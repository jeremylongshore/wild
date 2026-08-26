# frozen_string_literal: true

module Wild
  # Base of the consumer-distinguishable error tree (MIN-Armstrong, council rev2).
  #
  # Consumers can rescue at any level. Internal `rescue` clauses inside the
  # gem MUST be specific or re-raise after audit emission (F2 — every error
  # path emits a structured audit event).
  #
  # RESERVED, NOT YET RAISED (as of 2026-08-25, review wave finding f-x1-2):
  # eight subclasses below are defined and documented in the tree but no
  # `raise` site exists for any of them anywhere in lib/ today:
  # DeniedError, PolicyError, EvaluationError (CapabilityGate); ForbiddenError,
  # ModelNotAllowedError (Introspection); AuthenticationError; AnalysisError;
  # StorageError. `rescue`ing one of these today will never trigger from this
  # gem's own code paths. This is deliberate for CapabilityGate specifically
  # (deny-not-raise fail-closed design, F2), not yet decided for the rest. See
  # bead "F6: Audit and either wire or delete every half-published API
  # surface across the namespaces" (`wild-rvv.4.2`).
  #
  # Hierarchy (matches `000-docs/003-AT-ARCH-architecture.md § Error hierarchy`
  # verbatim):
  #
  #   Wild::Error                              (base)
  #   ├── Wild::ConfigurationError             (invalid config)
  #   ├── Wild::CapabilityGate::Error          (base for gate)
  #   │   ├── Wild::CapabilityGate::DeniedError
  #   │   ├── Wild::CapabilityGate::PolicyError
  #   │   └── Wild::CapabilityGate::EvaluationError    (F2 — never silent)
  #   ├── Wild::Introspection::Error
  #   │   ├── Wild::Introspection::ForbiddenError
  #   │   └── Wild::Introspection::ModelNotAllowedError
  #   ├── Wild::AdminTools::Error
  #   ├── Wild::Telemetry::Error
  #   ├── Wild::Hooks::Error
  #   ├── Wild::Analyzers::Error
  #   └── Wild::Skillops::Error
  #
  # Examples:
  #
  #   begin
  #     Wild::AdminTools.invoke!(...)
  #   rescue Wild::CapabilityGate::DeniedError => e
  #     # Specific: subject lacks the capability.
  #   rescue Wild::CapabilityGate::Error => e
  #     # Any capability-gate error including evaluation failure.
  #   rescue Wild::Error => e
  #     # Any wild error.
  #   end
  class Error < StandardError; end

  # Raised when Wild.configure is mis-used or required settings are absent.
  class ConfigurationError < Error; end

  # Namespace modules + per-namespace error subclasses.
  # These modules are declared here so the error classes can nest into them
  # before Role 5 lands per-namespace code in lib/wild/<namespace>/.
  module CapabilityGate
    # Base for every CapabilityGate failure mode.
    class Error < Wild::Error; end

    # Subject lacks the capability for the requested action.
    class DeniedError < Error; end

    # Policy file is malformed, missing, or self-inconsistent.
    class PolicyError < Error; end

    # F2 mandate: marks the "gate machinery itself broke" failure mode. The
    # shipped contract is fail-closed-DENY for genuine runtime/policy
    # failures: when `Evaluator#evaluate`'s `StandardError` rescue catches a
    # raise, it emits a structured audit event with `result:
    # "evaluation_error"` and returns a denial. The one deliberate exception
    # is a DEVELOPER_ERRORS member (AuditSchemaError and its subclass
    # AuditValidatorUnavailableError): those re-raise out of `evaluate`
    # instead of being demoted to a denial (f-l08-2/f-l08-3) — a developer bug
    # must surface loudly, not degrade the audit trail. Never silent: every
    # non-DEVELOPER_ERRORS failure is always paired with an audit event,
    # emitted BEFORE the denial is returned (see audit_liveness_spec ordering
    # examples, wild-rvv.4.1.1).
    #
    # This class is currently DECLARED but NOT RAISED anywhere — it is reserved
    # for an opt-in raising mode keyed off `Wild.config.capability_gate
    # .on_evaluation_error` (also currently inert). Whether to wire that mode or
    # cut both the class and the knob is tracked under wild-28y.
    class EvaluationError < Error; end

    # Raised when an emitted audit event fails validation against
    # `lib/wild/schemas/capability_gate/audit_event.yml` (F2, wild-rvv.4.1.2).
    # Fires ONLY when audit-event validation is enabled (dev/test by default,
    # off in prod): a non-conforming event is a developer bug that must surface
    # loudly, NOT be swallowed by the gate's fail-closed rescue. Production
    # (validation off) never raises this — the never-raises guarantee is a
    # production guarantee.
    class AuditSchemaError < Error; end

    # Raised specifically when audit-event validation is enabled but the
    # `json_schemer` development gem is not on the bundle (f-l08-2). Subclasses
    # AuditSchemaError, NOT Wild::ConfigurationError, so a single
    # `DEVELOPER_ERRORS = [AuditSchemaError]` whitelist at this namespace's
    # rescue sites (evaluator.rb, gate.rb) re-raises every developer-bug signal
    # from CapabilityGate with one class check, without also having to
    # whitelist the gem-wide Wild::ConfigurationError — which would let an
    # unrelated ConfigurationError from a future prerequisite checker escape
    # Evaluator#evaluate before its emit_audit call runs (f-l08 addendum item
    # 12). The message stays worded like a configuration problem even though
    # the class is not; deliberately not multiply-inherited from both
    # AuditSchemaError and ConfigurationError.
    class AuditValidatorUnavailableError < AuditSchemaError; end
  end

  module Introspection
    # Base for every Introspection failure mode.
    class Error < Wild::Error; end

    # MCP request forbidden by the active access policy.
    class ForbiddenError < Error; end

    # Requested model is not in `Wild.config.introspection.allowed_models`
    # (or the derived set when `allowed_models` is nil).
    class ModelNotAllowedError < Error; end

    # Access-policy / blocked-resources YAML is malformed or missing
    # (from wild-rails-safe-introspection-mcp).
    class ConfigError < Error; end

    # A tool attempted a write path against the read-only adapter.
    class WriteAttemptError < Error; end

    # A bounded query exceeded its configured timeout.
    class QueryTimeoutError < Error; end
  end

  module AdminTools
    # Base for every Wild::AdminTools failure mode.
    class Error < Wild::Error; end

    # Raised when a requested admin action is not in the allowlist.
    class ActionNotFoundError < Error
      attr_reader :action_name

      def initialize(action_name)
        @action_name = action_name
        super("Unknown action: #{action_name}")
      end
    end

    # Raised when action parameters fail validation. Carries the error list.
    class ValidationError < Error
      attr_reader :errors

      def initialize(errors)
        @errors = Array(errors)
        super("Validation failed: #{@errors.join(", ")}")
      end
    end

    # Raised when a job/cache/flag adapter operation fails. Wraps the cause.
    class AdapterError < Error
      attr_reader :original_error

      def initialize(message, original_error: nil)
        @original_error = original_error
        super(message)
      end
    end

    # Raised when caller identity cannot be established.
    class AuthenticationError < Error; end

    # Raised when the capability gate denies or errors. Wraps the cause.
    class GateError < Error
      attr_reader :original_error

      def initialize(message, original_error: nil)
        @original_error = original_error
        super(message)
      end
    end
  end

  module Telemetry
    class Error < Wild::Error; end

    # Collector sub-namespace errors (from wild-session-telemetry).
    module Collector
      class Error < Wild::Telemetry::Error; end

      # Raised when an event payload fails validation.
      class ValidationError < Error; end

      # Raised when an event does not conform to its declared schema.
      class SchemaError < Error; end

      # Raised when the backing store cannot persist or read events.
      class StorageError < Error; end
    end

    # Pipeline sub-namespace errors (from wild-transcript-pipeline).
    module Pipeline
      class Error < Wild::Telemetry::Error; end

      # Raised when an ingestion adapter cannot parse its input.
      class IngestionError < Error; end

      # Raised when turn/intent/tool normalization fails.
      class NormalizationError < Error; end

      # Raised when privacy redaction fails.
      class PrivacyError < Error; end

      # Raised when transcript export fails.
      class ExportError < Error; end
    end

    # Analysis sub-namespace errors (from wild-gap-miner).
    module Analysis
      class Error < Wild::Telemetry::Error; end

      # Raised when a telemetry export file cannot be parsed.
      class ParseError < Error; end

      # Raised when a record fails validation.
      class ValidationError < Error; end

      # Raised when an export record does not conform to its schema.
      class SchemaError < Error; end

      # Raised when gap-report export fails.
      class ExportError < Error; end
    end
  end

  module Hooks
    # Base for every Wild::Hooks failure mode.
    class Error < Wild::Error; end

    # Raised when a hook definition with the given name is not found.
    class HookNotFoundError < Error
      def initialize(hook_name)
        super("Hook definition not found: #{hook_name.inspect}")
      end
    end

    # Raised when attempting to register a duplicate hook definition.
    class DuplicateHookError < Error
      def initialize(hook_name)
        super("Hook definition already registered: #{hook_name.inspect}")
      end
    end

    # Raised when the handler store has reached max_handlers_per_hook.
    class HandlerLimitExceededError < Error
      def initialize(hook_name, limit)
        super("Handler limit (#{limit}) exceeded for hook: #{hook_name.inspect}")
      end
    end

    # Raised when a handler callable does not respond to #call.
    class InvalidHandlerError < Error
      def initialize(msg = "Handler must respond to #call")
        super
      end
    end
  end

  module Analyzers
    # Base for every Wild::Analyzers failure mode.
    class Error < Wild::Error; end

    # Permission analyzer sub-namespace errors (from wild-permission-analyzer).
    module Permission
      class Error < Wild::Analyzers::Error; end

      # Raised when a capabilities/grants file cannot be loaded or parsed.
      class LoadError < Error; end

      # Raised when an analysis pass fails on otherwise-valid input.
      class AnalysisError < Error; end

      # Raised when report export fails.
      class ExportError < Error; end
    end

    # TestFlakes sub-namespace errors (from wild-test-flake-forensics).
    module TestFlakes
      class Error < Wild::Analyzers::Error; end

      # Raised when a test-result report (rspec/junit/minitest) cannot be parsed.
      class ParseError < Error; end

      # Raised when flake detection fails on otherwise-valid input.
      class DetectionError < Error; end

      # Raised when report export fails.
      class ExportError < Error; end
    end
  end

  module Skillops
    # Base for every Wild::Skillops failure mode.
    class Error < Wild::Error; end

    # Raised when an application invokes the internal Skillops registry without
    # explicitly opting in through `Wild.config.skillops.enabled`.
    class DisabledError < Error; end

    # Raised when a skill registration payload fails validation.
    class ValidationError < Error; end

    # Raised when a referenced skill does not exist in the registry.
    class NotFoundError < Error; end

    # Raised when a duplicate skill name is registered without explicit update.
    class DuplicateSkillError < Error; end

    # Raised when a lifecycle transition is not permitted.
    class LifecycleError < Error; end

    # Raised when the registry exceeds its configured capacity
    # (Wild.config.skillops.max_skills).
    class RegistryCapacityError < Error; end

    # Raised when a skill version limit is exceeded
    # (Wild.config.skillops.max_versions_per_skill).
    class VersionCapacityError < Error; end
  end
end
