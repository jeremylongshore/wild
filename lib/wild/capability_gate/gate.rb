# frozen_string_literal: true

module Wild
  module CapabilityGate
    # The public interface for consuming repos.
    #
    # Wraps the internal components (registry, evaluator, audit writer) behind
    # a minimal, stable API. This is the contract other repos design against.
    #
    # Usage:
    #   gate = Wild::CapabilityGate.new(config_path: "config/capability_gate")
    #   result = gate.evaluate(caller: "service-account:agent", capability: :basic_introspection)
    #   result.allowed? # => true
    #
    # See 006-AT-STND-interface-contract.md for the full interface specification.
    class Gate
      # Initialize the gate from a configuration directory.
      #
      # The config_path directory must contain:
      #   - capabilities.yml — capability definitions
      #   - grants.yml — caller-to-capability grant mappings
      #
      # Optional:
      #   - audit_log_path: path to the JSON Lines audit log file
      #   - session_id: session identifier for audit events
      #
      # Raises on configuration errors — broken config must be caught at startup,
      # not silently swallowed during evaluation.
      def initialize(config_path:, audit_log_path: nil, session_id: nil)
        config_path = String(config_path)
        @evaluator = build_evaluator(config_path, audit_log_path, session_id)
        @registry = Registry.from_file(File.join(config_path, "capabilities.yml"))
      end

      # Evaluate whether the caller is granted the named capability.
      #
      # Returns an EvaluationResult for every policy/runtime outcome, never
      # raises for those. If evaluation fails for any reason at that layer, the
      # result is denial with reason :evaluation_error (fail-closed per Doc 003).
      #
      # f-l08-3: a developer-facing config/schema bug (a non-conforming audit
      # event, or audit-schema validation enabled with `json_schemer` absent)
      # is NOT a policy/runtime outcome, it re-raises through this method,
      # matching #initialize's existing "raises on configuration errors, does
      # not silently swallow them" contract, rather than being demoted to an
      # audit-blind :evaluation_error denial.
      def evaluate(caller:, capability:, context: {})
        @evaluator.evaluate(caller_id: caller, capability_name: capability, context: context)
      rescue Wild::CapabilityGate::AuditSchemaError, Wild::ConfigurationError
        raise
      rescue StandardError => e
        deny_with_error(caller, capability, e)
      end

      # List all known capabilities (read-only).
      # Returns an array of Capability objects.
      def capabilities
        @registry.all
      end

      private

      def build_evaluator(config_path, audit_log_path, session_id)
        audit_writer = audit_log_path ? Audit::JsonLinesWriter.new(path: audit_log_path) : nil
        Evaluator.from_files(
          capabilities_path: File.join(config_path, "capabilities.yml"),
          grants_path: File.join(config_path, "grants.yml"),
          audit_writer: audit_writer, session_id: session_id
        )
      end

      # Last-resort safety net for genuine runtime/policy failures. Reaching
      # here means Evaluator#evaluate raised something other than the two
      # config/schema errors #evaluate re-raises above: that is a BUG, not a
      # policy outcome, and this path is audit-blind BY CONSTRUCTION (the Gate
      # holds no audit writer; emission lives in the Evaluator where the
      # writer is). The Evaluator's own rescue emits the evaluation_error
      # event for every real failure; if execution reaches here the
      # Evaluator's contract has been violated and the missing audit event is
      # the signal. Pinned by a Gate-rescue contract test (wild-rvv.4.1
      # fast-follow per Armstrong F2 sign-off). Still fails closed.
      #
      # f-l08-3 correction: this rescue is NOT unreachable today (a prior
      # version of this comment, and gate_spec.rb, both claimed it was).
      # Evaluator#evaluate deliberately re-raises AuditSchemaError, and this
      # StandardError rescue used to be the ONLY thing catching it: silently
      # demoting a "surface loudly" developer-bug signal into an audit-blind
      # :evaluation_error denial. The explicit rescue added above now
      # intercepts AuditSchemaError and ConfigurationError before they reach
      # here.
      def deny_with_error(caller_value, capability, error)
        EvaluationResult.denied(
          capability_name: capability || :unknown,
          caller_id: String(caller_value),
          reason: :evaluation_error,
          details: "evaluation failed: #{error.class}"
        )
      end
    end
  end
end
