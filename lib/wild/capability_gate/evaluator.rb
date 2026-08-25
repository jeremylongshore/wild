# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Coercions that must NEVER raise — used inside Evaluator#evaluate's rescue
    # handler, where a second raise would propagate an exception with no audit
    # written (the F2 hole this gate exists to close). Extracted as a collaborator
    # so the originating raise (a hostile caller_id/capability whose #to_s/#to_sym
    # itself raises) collapses to a stable, greppable placeholder instead.
    # (Armstrong F2 gate, wild-rvv.4.1.1.)
    module SafeCoercion
      private

      # Coerce to a Symbol without ever raising; nil or a raising #to_sym → :unknown.
      def safe_symbol(value)
        value&.to_sym || :unknown
      rescue StandardError
        :unknown
      end

      # Coerce to a String without ever raising; a raising #to_s → placeholder.
      def safe_caller_id(value)
        String(value)
      rescue StandardError
        "<uncoercible-caller-id>"
      end

      # #message on an arbitrary rescued exception is not guaranteed safe (a
      # pathological exception can override it to raise). Degrade to a placeholder
      # rather than lose a should-have-logged line (Armstrong F2 finding 4,
      # wild-wxk).
      def safe_message(error)
        error.message
      rescue StandardError
        "<unprintable message>"
      end

      # Coerce to a Hash without ever raising. A caller-supplied `context` that
      # Hash() cannot convert (a String, an Array that is not pairs, any object
      # whose #to_hash itself raises) degrades to a placeholder hash carrying
      # the offending value's inspect rather than blowing up event construction
      # (f-l08-1: one non-Hash `context` argument on the documented public
      # `evaluate` entry point used to raise inside Audit::Event#initialize,
      # get swallowed by emit_audit's rescue, and leave the ALLOW/DENY result
      # with NO audit line written).
      def safe_context(value)
        Hash(value)
      rescue StandardError
        { raw: safe_inspect(value) }
      end

      # #inspect on an arbitrary value is not guaranteed safe either; degrade
      # rather than raise while building the safe_context placeholder.
      def safe_inspect(value)
        value.inspect[0, 200]
      rescue StandardError
        "<uninspectable>"
      end

      # Log an audit emission failure without ever raising (Evaluator#emit_audit
      # calls this from its own rescue: a raise here would defeat the
      # never-raises guarantee). f-l08-4: Wild.config.audit_logger defaults to
      # nil, so without the warn fallback a single writer failure was
      # terminally silent while ALLOW/DENY was still returned. Kernel#warn
      # ($stderr) is always available and keeps "audit failure is never
      # doubly silent" true out of the box, not only when a caller explicitly
      # configures a logger.
      def log_audit_failure(error, result)
        message = build_audit_failure_message(error, result)
        logger = Wild.config.audit_logger
        logger.respond_to?(:error) ? logger.error(message) : warn(message)
      rescue StandardError
        # The configured logger raised from #error, or message construction
        # itself raised. Rebuild the message fresh rather than rely on a
        # binding from the failed attempt; only an unwritable $stderr defeats
        # this last resort.
        begin
          warn build_audit_failure_message(error, result)
        rescue StandardError
          nil
        end
      end

      # error.class is always safe; error.message is guarded via safe_message
      # (a pathological exception whose #message raises must not turn a
      # should-have-logged into terminal silence). Armstrong F2 fast-follow
      # finding 4 (wild-wxk).
      def build_audit_failure_message(error, result)
        "[wild:capability_gate] audit emission failed: #{error.class}: #{safe_message(error)} " \
          "(caller=#{result.caller_id.inspect} capability=#{result.capability_name.inspect} " \
          "reason=#{result.reason.inspect})"
      end
    end

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
      include SafeCoercion

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
      rescue Wild::CapabilityGate::AuditSchemaError, Wild::ConfigurationError
        # F2 (wild-rvv.4.1.2) + f-l08-2: a non-conforming audit event, or an
        # audit-validator misconfiguration (validation enabled but the
        # `json_schemer` gem is absent: schema_validator.rb's ConfigurationError),
        # is a developer bug, not a runtime fault: surface it loudly rather than
        # let it degrade to a silent ALLOW/DENY with zero audit and zero log. This
        # only fires when validation is enabled (dev/test by default), so
        # production (validation off) keeps the never-raises guarantee untouched.
        # Must come BEFORE the StandardError rescue, or either error would be
        # misreported as an evaluation_error denial.
        raise
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
        # This runs INSIDE evaluate's rescue handler — it must NEVER raise, or
        # evaluate would propagate an exception with no audit written (the exact
        # F2 hole this path exists to close). The original raise may have been
        # the coercion of a hostile caller_id/capability (a `to_s`/`to_sym` that
        # itself raises), so re-coerce defensively with literal fallbacks rather
        # than String()/to_sym directly. (Armstrong F2 gate, wild-rvv.4.1.1.)
        EvaluationResult.denied(
          capability_name: safe_symbol(capability_name),
          caller_id: safe_caller_id(caller_id),
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

        # f-l08-1: coerce defensively BEFORE Event construction. A hostile
        # `context` (a String, a non-pair Array, an object whose #to_hash
        # raises) used to blow up `Hash(context)` inside Audit::Event#initialize;
        # that raise was caught below by the StandardError rescue and, with the
        # default nil audit_logger, produced zero audit record and zero log line
        # for an ALLOW/DENY that had already been decided. safe_context never
        # raises, so event construction always succeeds and this method's own
        # rescue clauses are reserved for genuine write/validation failures.
        event = Audit::Event.from_evaluation(
          result, registry: @registry, session_id: @session_id, context: safe_context(context)
        )
        # F2 (wild-rvv.4.1.2): in dev/test, prove the event conforms to
        # audit_event.yml BEFORE it is written. A schema violation re-raises
        # (caught by evaluate's AuditSchemaError rescue → surfaces as a dev/test
        # failure); it is NOT swallowed by the StandardError rescue below, which
        # exists for genuine write/IO failures. Off in prod by default.
        Audit::SchemaValidator.validate!(event.to_h) if Audit::SchemaValidator.enabled?
        @audit_writer.write(event)
      rescue Wild::CapabilityGate::AuditSchemaError, Wild::ConfigurationError
        # f-l08-2: SchemaValidator.validate! (via its private `schemer` method)
        # raises Wild::ConfigurationError when validation is enabled but the
        # `json_schemer` gem is not on the bundle. That was previously caught by
        # the StandardError rescue below and, with audit_logger nil by default,
        # every evaluation silently returned ALLOW/DENY with zero audit and zero
        # log: an absent dev dependency should fail loudly at first use, not
        # degrade the gate's audit trail. Re-raise here, ordered before
        # StandardError, exactly as AuditSchemaError already does.
        raise
      rescue StandardError => e
        # log_audit_failure lives in SafeCoercion (never raises out of here by
        # contract; also shared with the module's other never-raising helpers).
        log_audit_failure(e, result)
        nil
      end
    end
  end
end
