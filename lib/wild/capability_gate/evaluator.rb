# frozen_string_literal: true

module Wild
  module CapabilityGate
    # Developer-bug signals from this namespace that must surface loudly
    # rather than be swallowed into a policy denial or a generic evaluation
    # failure. AuditSchemaError's own subclass AuditValidatorUnavailableError
    # (raised when the `json_schemer` gem is absent) is covered by this single
    # class check without also whitelisting the gem-wide Wild::ConfigurationError
    # — an unrelated ConfigurationError raised by some future prerequisite
    # checker must NOT get a free pass out of Evaluator#evaluate ahead of its
    # emit_audit call (f-l08 addendum item 12). Referenced by evaluator.rb,
    # gate.rb, and (T4, allowed under ADR-0003) admin_tools' GateClient.
    DEVELOPER_ERRORS = [AuditSchemaError].freeze

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
    # rubocop:disable Metrics/ClassLength -- carries the full decision tree AND
    # the f-l08 addendum's audit-failure logging helpers (log_audit_failure/
    # write_stderr/build_audit_failure_message); those exist only to serve this
    # class's own never-raises guarantee, so splitting them out would separate
    # the guarantee from its enforcement.
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
      # Returns an EvaluationResult for every genuine policy/runtime outcome —
      # never raises for those. The one exception is a DEVELOPER_ERRORS member
      # (a non-conforming audit event, or audit-schema validation enabled with
      # `json_schemer` absent): that is a developer bug, not a runtime fault,
      # and is re-raised deliberately rather than degraded to a silent denial
      # (f-l08-2/f-l08-3).
      #
      # When an audit_writer is configured, every evaluation emits an audit event
      # before the result is returned. This satisfies the audit completeness rule
      # from 003-TQ-STND-governance-model.md Section 5.
      def evaluate(caller_id:, capability_name:, context: {})
        capability_name = capability_name.to_sym
        caller_id = String(caller_id)
        # f-l08 addendum item 10: coerce ONCE, here, and pass the SAME coerced
        # Hash to both the prerequisite checker and emit_audit. Previously the
        # prerequisite checker saw the raw (possibly hostile) context while
        # emit_audit recorded a separately, safely coerced one — a String
        # context crashed ConfigValueChecker (masked as an ordinary
        # prerequisite_not_met denial by its own rescue) while the audit trail
        # recorded `{}`, an inconsistency between what was decided on and what
        # was audited. Audit::Event.coerce_context never raises.
        context = Audit::Event.coerce_context(context)

        result = check_capability_known(caller_id, capability_name) ||
                 check_caller_granted(caller_id, capability_name) ||
                 check_prerequisites(caller_id, capability_name, context) ||
                 allow_with_prerequisites(caller_id, capability_name)

        emit_audit(result, context)
        result
      rescue *DEVELOPER_ERRORS
        # F2 (wild-rvv.4.1.2) + f-l08-2: a non-conforming audit event, or an
        # audit-validator misconfiguration (validation enabled but the
        # `json_schemer` gem is absent: AuditValidatorUnavailableError), is a
        # developer bug, not a runtime fault: surface it loudly rather than
        # let it degrade to a silent ALLOW/DENY with zero audit and zero log.
        # This only fires when validation is enabled (dev/test by default), so
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
        # matching audit event before returning. Re-raise nothing here — every
        # StandardError other than a DEVELOPER_ERRORS member fails closed
        # instead of escaping evaluate.
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
      # either: the failure is logged (Wild.config.audit_logger, or $stderr as a
      # fallback) so an audit-pipeline outage is itself observable. Audit
      # failure ≠ silent.
      def emit_audit(result, context)
        return unless @audit_writer

        # `context` arrives already coerced (evaluate coerces it once, up
        # front — f-l08 addendum item 10); Event#initialize also re-coerces
        # defensively as a total-construction backstop for any other caller of
        # Event.new, so passing it through again here is cheap and safe, never
        # a second source of truth.
        event = Audit::Event.from_evaluation(
          result, registry: @registry, session_id: @session_id, context: context
        )
        # f-l08 addendum item 13: build the hash once, hand the SAME hash to
        # both the validator and the writer, rather than each independently
        # calling event.to_h.
        event_hash = event.to_h
        # F2 (wild-rvv.4.1.2): in dev/test, prove the event conforms to
        # audit_event.yml BEFORE it is written. A schema violation re-raises
        # (caught by evaluate's DEVELOPER_ERRORS rescue → surfaces as a dev/test
        # failure); it is NOT swallowed by the StandardError rescue below, which
        # exists for genuine write/IO failures. Off in prod by default.
        Audit::SchemaValidator.validate!(event_hash) if Audit::SchemaValidator.enabled?
        @audit_writer.write(event_hash)
      rescue *DEVELOPER_ERRORS
        # f-l08-2: SchemaValidator.validate! (via its private `schemer` method)
        # raises AuditValidatorUnavailableError when validation is enabled but
        # the `json_schemer` gem is not on the bundle. That was previously
        # caught by the StandardError rescue below and, with audit_logger nil
        # by default, every evaluation silently returned ALLOW/DENY with zero
        # audit and zero log: an absent dev dependency should fail loudly at
        # first use, not degrade the gate's audit trail. Re-raise here, ordered
        # before StandardError, exactly as the schema-conformance case does.
        raise
      rescue StandardError => e
        log_audit_failure(e, result)
        nil
      end

      # Log an audit emission failure without ever raising (this method's own
      # caller, emit_audit's rescue, must not raise either — that would defeat
      # the never-raises guarantee). f-l08-4: Wild.config.audit_logger defaults
      # to nil, so without a fallback a single writer failure was terminally
      # silent while ALLOW/DENY was still returned.
      #
      # f-l08 addendum item 1: `Kernel#warn` is a no-op when `$VERBOSE` is nil
      # (`ruby -W0`, `RUBYOPT=-W0`, a caller that runs under `silence_warnings`)
      # — the specs here only ever passed because spec_helper.rb sets
      # `config.warnings = false`, which does NOT affect `$VERBOSE`. Writing to
      # `$stderr` directly keeps "audit failure is never doubly silent" true
      # regardless of the process's warning-verbosity setting; only an
      # unwritable $stderr defeats this last resort.
      def log_audit_failure(error, result)
        message = build_audit_failure_message(error, result)
        logger = Wild.config.audit_logger
        logger.respond_to?(:error) ? logger.error(message) : write_stderr(message)
      rescue StandardError
        # The configured logger raised from #error, or message construction
        # itself raised (message stays nil in that case — Ruby has already
        # declared the local by the time this rescue runs). Reuse the message
        # we already built when we have one instead of rebuilding it (which
        # would risk raising the exact same way twice); fall back to a
        # class-only line when we don't.
        write_stderr(message || "[wild:capability_gate] audit emission failed: #{error.class}")
      end

      # @api private
      # rubocop:disable Style/StderrPuts -- deliberate: `warn` is a Kernel#warn
      # no-op under $VERBOSE = nil (ruby -W0, silence_warnings), which is
      # exactly the f-l08 addendum item 1 finding this bypasses.
      def write_stderr(line)
        $stderr.puts(line)
      rescue StandardError
        nil
      end
      # rubocop:enable Style/StderrPuts

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
    # rubocop:enable Metrics/ClassLength
  end
end
