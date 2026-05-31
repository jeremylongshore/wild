# frozen_string_literal: true

module Wild
  module CapabilityGate
    # The core access decision engine.
    #
    # Given a caller identity and capability name, determines whether the caller
    # is granted that capability based on grants and prerequisite satisfaction.
    #
    # Decision tree (from 002-AT-STND-capability-model.md):
    # 1. Is capability known?            → No: DENY(unknown_capability)
    # 2. Is caller granted?              → No: DENY(not_granted)
    # 3. Are all prerequisites satisfied? → No: DENY(prerequisite_not_met)
    # 4. ALLOW
    #
    # See also: 003-TQ-STND-governance-model.md (fail-closed, no implicit grants)
    class Evaluator
      require_relative "evaluator/grant_loader"

      def initialize(registry:, grants:, audit_writer: nil, session_id: nil)
        @registry = registry
        @grants = Array(grants).freeze
        @audit_writer = audit_writer
        @session_id = session_id
        freeze
      end

      def self.from_files(capabilities_path:, grants_path:, audit_writer: nil, session_id: nil)
        registry = Registry.from_file(capabilities_path)
        grants = GrantLoader.load_file(grants_path)
        new(registry: registry, grants: grants, audit_writer: audit_writer, session_id: session_id)
      end

      # Evaluate whether the caller is granted the named capability.
      # Context provides runtime values for prerequisite checks (e.g., config values).
      # Returns an EvaluationResult — always, never raises.
      #
      # When an audit_writer is configured, every evaluation emits an audit event
      # before the result is returned. This satisfies the audit completeness rule
      # from 003-TQ-STND-governance-model.md Section 5.
      def evaluate(caller_id:, capability_name:, context: {})
        capability_name = capability_name.to_sym
        caller_id = String(caller_id)

        result = check_capability_known(caller_id, capability_name) ||
                 check_caller_granted(caller_id, capability_name) ||
                 check_prerequisites(caller_id, capability_name, context) ||
                 allow_with_prerequisites(caller_id, capability_name)

        emit_audit(result, context)
        result
      rescue StandardError => e
        # F2 (council rev2, Armstrong): the decision logic raised — fail closed
        # AND leave an audit trail. The prerequisite checkers are fail-closed
        # today, so this is defense-in-depth: a corrupted registry/grant, a
        # future checker bug, or Event construction blowing up must NOT produce
        # a silent denial. Deny with reason :evaluation_error and emit the
        # matching audit event before returning. Re-raise nothing — the gate
        # never raises out of evaluate.
        error_result = deny_evaluation_error(caller_id, capability_name, e)
        emit_audit(error_result, context)
        error_result
      end

      private

      def deny_evaluation_error(caller_id, capability_name, error)
        EvaluationResult.denied(
          # caller_id / capability_name may not have coerced if the raise
          # happened during coercion; String()/to_sym defensively.
          capability_name: capability_name&.to_sym || :unknown,
          caller_id: String(caller_id),
          reason: :evaluation_error,
          details: "evaluation failed: #{error.class}"
        )
      end

      def check_capability_known(caller_id, capability_name)
        return if @registry.known?(capability_name)

        EvaluationResult.denied(
          capability_name: capability_name, caller_id: caller_id,
          reason: :unknown_capability,
          details: "capability #{capability_name.inspect} is not registered"
        )
      end

      def check_caller_granted(caller_id, capability_name)
        return if @grants.any? { |g| g.matches_caller?(caller_id) && g.grants_capability?(capability_name) }

        EvaluationResult.denied(
          capability_name: capability_name, caller_id: caller_id,
          reason: :not_granted,
          details: "caller #{caller_id.inspect} is not granted #{capability_name.inspect}"
        )
      end

      def check_prerequisites(caller_id, capability_name, context)
        capability = @registry.fetch(capability_name)
        return if capability.prerequisites.empty?

        checker = Prerequisites::Checker.new(context: context)
        result = checker.check_all(capability.prerequisites)
        return if result.satisfied?

        EvaluationResult.denied(
          capability_name: capability_name, caller_id: caller_id,
          reason: :prerequisite_not_met,
          details: result.details
        )
      end

      def allow_with_prerequisites(caller_id, capability_name)
        capability = @registry.fetch(capability_name)
        checked = capability.prerequisites.map(&:type)

        EvaluationResult.allowed(
          capability_name: capability_name,
          caller_id: caller_id,
          prerequisites_checked: checked
        )
      end

      # Emit audit event if a writer is configured.
      # Called after every evaluation, before the result is returned to the caller.
      # An audit-write failure must not cause the gate to raise (fail-closed
      # still applies) — but per F2 (council rev2) it must NOT be doubly silent
      # either: the failure is logged to Wild.config.audit_logger so an
      # audit-pipeline outage is itself observable. Audit failure ≠ silent.
      def emit_audit(result, context)
        return unless @audit_writer

        event = Audit::Event.from_evaluation(
          result, registry: @registry, session_id: @session_id, context: context
        )
        @audit_writer.write(event)
      rescue StandardError => e
        log_audit_failure(e, result)
        nil
      end

      def log_audit_failure(error, result)
        logger = Wild.config.audit_logger
        return unless logger.respond_to?(:error)

        logger.error(
          "[wild:capability_gate] audit emission failed: #{error.class}: #{error.message} " \
          "(caller=#{result.caller_id.inspect} capability=#{result.capability_name.inspect} " \
          "reason=#{result.reason.inspect})"
        )
      rescue StandardError
        # The audit logger itself is broken. There is nowhere left to write;
        # do not raise out of the gate. This is the one genuinely-terminal
        # silent path, and it requires BOTH the audit writer AND the configured
        # logger to be broken simultaneously.
        nil
      end
    end
  end
end
