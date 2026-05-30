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
      # Returns an EvaluationResult — always. Never raises.
      # If evaluation fails for any reason, the result is denial with
      # reason :evaluation_error (fail-closed per Doc 003).
      def evaluate(caller:, capability:, context: {})
        @evaluator.evaluate(caller_id: caller, capability_name: capability, context: context)
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
