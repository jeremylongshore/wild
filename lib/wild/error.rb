# frozen_string_literal: true

module Wild
  # Base of the consumer-distinguishable error tree (MIN-Armstrong, council rev2).
  #
  # Consumers can rescue at any level. Internal `rescue` clauses inside the
  # gem MUST be specific or re-raise after audit emission (F2 — every error
  # path emits a structured audit event).
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

    # F2 mandate: raised when a `rescue` path in the gate emits a structured
    # audit event with `outcome: :evaluation_error` and denies the request.
    # Never silent — always paired with an audit event.
    class EvaluationError < Error; end
  end

  module Introspection
    # Base for every Introspection failure mode.
    class Error < Wild::Error; end

    # MCP request forbidden by the active access policy.
    class ForbiddenError < Error; end

    # Requested model is not in `Wild.config.introspection.allowed_models`
    # (or the derived set when `allowed_models` is nil).
    class ModelNotAllowedError < Error; end
  end

  module AdminTools
    class Error < Wild::Error; end
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
