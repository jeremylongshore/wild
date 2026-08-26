# frozen_string_literal: true

require "time"
require "securerandom"
require "json"

module Wild
  module CapabilityGate
    module Audit
      # Immutable audit event produced by every capability evaluation.
      #
      # The serialized shape (`#to_h`) is the published contract in
      # `lib/wild/schemas/capability_gate/audit_event.yml`; a round-trip
      # conformance spec validates this output against that schema so the two
      # cannot silently drift (wild-rvv.4.1.3). Every evaluation — allow, deny,
      # or evaluation_error — produces exactly one of these.
      #
      # F2 (council rev2): `evaluation_error` is the sentinel outcome for "the
      # gate machinery broke and failed closed" — distinct from a policy `deny`.
      # Because Events are constructed inside Evaluator#evaluate's rescue handler,
      # construction MUST NOT raise (a raise here re-opens the silent-denial hole
      # F2 exists to close): the outcome remap is total, and policy_version is
      # resolved defensively.
      # rubocop:disable Metrics/ClassLength -- the class carries both the 12-field
      # value-object contract AND the f-l08 addendum's bounded context-coercion
      # helpers (hash_context/placeholder_for/sanitized_placeholder/bound_context);
      # splitting coercion into a second file would separate it from the single
      # invariant it exists to protect (Event construction never raises).
      class Event
        # The contract's outcome enum (audit_event.yml). `allowed`/`denied` from
        # the EvaluationResult map to the contract's `allow`/`deny`.
        VALID_OUTCOMES = %w[allow deny evaluation_error].freeze
        UNKNOWN_OUTCOME = "evaluation_error"

        # Context-coercion bounds (f-l08 addendum items 4 + 11). Coercion must
        # never raise (Events are built inside Evaluator#evaluate's rescue
        # handler) AND must never do unbounded work on a hostile context: a
        # blanket #inspect on an arbitrary value is itself dangerous — slow for
        # a multi-megabyte String, and fatal for a very deeply nested Array,
        # whose recursive #inspect raises SystemStackError. SystemStackError is
        # NOT a StandardError, so it would escape every rescue clause here (and
        # every rescue in Evaluator#evaluate) with zero audit lines written —
        # exactly the F2 hole this coercion exists to close.
        CONTEXT_INSPECT_LIMIT = 200
        CONTEXT_JSON_BYTE_LIMIT = 2048
        CONTEXT_JSON_MAX_NESTING = 16
        CONTEXT_KEY_LIMIT = 16

        attr_reader :timestamp, :decision_id, :subject, :capability, :risk_level,
                    :outcome, :reason, :rationale, :policy_version,
                    :prerequisites_checked, :prerequisites_passed, :session_id, :context

        # Build an audit event from an EvaluationResult and supplementary data.
        # This is the primary factory — ensures schema consistency.
        def self.from_evaluation(evaluation_result, registry:, session_id: nil, context: {})
          attrs = extract_attrs(evaluation_result, registry)
          new(**attrs, session_id: session_id, context: context)
        end

        # Coerce an arbitrary caller-supplied value into a safe, bounded Hash
        # suitable for the audit `context` field. NEVER raises. Public (not
        # just an Event-internal helper) so Evaluator#evaluate can coerce
        # context ONCE, up front, and hand the SAME coerced Hash to both the
        # prerequisite checkers and the audit trail (f-l08 addendum item 10) —
        # previously the checkers saw the raw, possibly hostile context while
        # the audit line recorded a separately-coerced one, so what was
        # decided on and what was audited could disagree.
        def self.coerce_context(value)
          bound_context(hash_context(value))
        end

        # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize -- value object mirroring the 12-field audit_event.yml schema; ABC is inherent to assigning + lightly coercing each field
        def initialize(timestamp:, subject:, capability:, risk_level:, outcome:,
                       policy_version:, decision_id: nil, reason: nil, rationale: nil,
                       prerequisites_checked: [], prerequisites_passed: true,
                       session_id: nil, context: {})
          @timestamp = timestamp
          @decision_id = decision_id || SecureRandom.uuid
          @subject = String(subject)
          @capability = String(capability)
          @risk_level = String(risk_level)
          @outcome = normalize_outcome(outcome)
          @reason = reason&.to_s
          @policy_version = String(policy_version)
          @rationale = rationale&.to_s || derive_rationale(@outcome, @reason)
          @prerequisites_checked = Array(prerequisites_checked).freeze
          @prerequisites_passed = prerequisites_passed
          @session_id = session_id
          # f-l08-1 + addendum item 4: re-coerce defensively even when the
          # caller (Evaluator#evaluate) already coerced context once — this is
          # the total-construction backstop for any OTHER caller of Event.new
          # (a test double, a future consumer). self.class.coerce_context never
          # raises AND always hands back a Hash that is NOT the caller's own
          # object (see .hash_context below), so freezing it here never freezes
          # a Hash the caller still holds a live, mutable reference to — the
          # FrozenError trap the un-dup'd `Hash(context)` used to spring.
          @context = self.class.coerce_context(context).freeze
          freeze
        end
        # rubocop:enable Metrics/ParameterLists, Metrics/AbcSize

        # Serialize to the JSON-compatible hash matching audit_event.yml.
        # Decision-core fields are first-class; consumer-open correlation
        # (session_id) + arbitrary context live under `extra`.
        def to_h
          build_hash
        end

        private

        def build_hash
          { "timestamp" => @timestamp.utc.iso8601(3),
            "decision_id" => @decision_id,
            "capability" => @capability,
            "subject" => @subject,
            "outcome" => @outcome,
            "policy_version" => @policy_version,
            "rationale" => @rationale,
            "reason" => @reason,
            "risk_level" => @risk_level,
            "prerequisites_checked" => @prerequisites_checked,
            "prerequisites_passed" => @prerequisites_passed,
            "extra" => { "session_id" => @session_id, "context" => @context } }
        end

        # Total — never raises (runs inside the rescue path). An unrecognized
        # outcome collapses to the evaluation_error sentinel rather than raising,
        # so a future stray value can never produce a silent (auditless) denial.
        def normalize_outcome(outcome)
          str = String(outcome)
          VALID_OUTCOMES.include?(str) ? str : UNKNOWN_OUTCOME
        rescue StandardError
          UNKNOWN_OUTCOME
        end

        # Non-empty one-liner (schema requires minLength 1).
        def derive_rationale(outcome, reason)
          case outcome
          when "allow" then "granted"
          when "evaluation_error" then reason ? "evaluation_error:#{reason}" : "evaluation_error"
          else reason ? "denied:#{reason}" : "denied"
          end
        end

        class << self
          private

          def extract_attrs(evaluation_result, registry)
            capability_name = evaluation_result.capability_name
            core_attrs(evaluation_result, capability_name, registry)
              .merge(prerequisite_attrs(evaluation_result))
          end

          def core_attrs(evaluation_result, capability_name, registry)
            { timestamp: evaluation_result.timestamp,
              subject: evaluation_result.caller_id,
              capability: capability_name.to_s,
              risk_level: resolve_risk_level(capability_name, registry),
              outcome: outcome_for(evaluation_result),
              policy_version: resolve_policy_version(registry),
              reason: evaluation_result.reason&.to_s }
          end

          # F2: an evaluation_error denial records the distinct `evaluation_error`
          # outcome, not the generic `deny`. Allowed → "allow"; any other
          # denial → "deny". (Contract enum: allow/deny/evaluation_error.)
          def outcome_for(evaluation_result)
            return "allow" if evaluation_result.allowed?
            return "evaluation_error" if evaluation_result.reason == :evaluation_error

            "deny"
          end

          def prerequisite_attrs(evaluation_result)
            { prerequisites_checked: evaluation_result.prerequisites_checked.map(&:to_s),
              prerequisites_passed: evaluation_result.allowed? || !prerequisite_failure?(evaluation_result) }
          end

          def resolve_risk_level(capability_name, registry)
            cap = registry.find(capability_name)
            cap ? cap.risk_level.to_s : "unknown"
          end

          # Resolved at Registry load and frozen, so reading it on the audit
          # (incl. rescue) path does no I/O and never raises. A registry without
          # a fingerprint (e.g. a test stub) yields the all-zero sentinel rather
          # than blowing up the audit emission.
          def resolve_policy_version(registry)
            registry.respond_to?(:policy_version) ? registry.policy_version : Registry::UNKNOWN_POLICY_VERSION
          rescue StandardError
            Registry::UNKNOWN_POLICY_VERSION
          end

          def prerequisite_failure?(evaluation_result)
            evaluation_result.denied? && evaluation_result.reason == :prerequisite_not_met
          end

          # --- context coercion (f-l08 addendum items 4, 11) ---

          # Hash(value) succeeds ONLY for a real Hash (via Hash#to_hash, which
          # returns the SAME object — #dup below is what makes this a copy,
          # not Hash()), or for nil / an empty Array (both become {}). Kernel#Hash
          # raises TypeError for EVERY other Array, including one that looks
          # like key/value pairs — Array does not implement #to_hash, and
          # Hash() does not fall back to #to_h (a prior version of this comment
          # claimed pairs arrays convert; verified false: `Hash([["a",1]])`
          # raises TypeError just like `Hash(%w[x y])` does — f-l08 addendum
          # item 8). So a String, ANY non-empty Array, or an object whose
          # #to_hash itself raises all degrade to the placeholder branch below.
          # @api private
          def hash_context(value)
            Hash(value).dup
          rescue StandardError, SystemStackError
            { raw: sanitized_placeholder(value) }
          end

          # Class-dispatched, and deliberately never calls #inspect on the
          # whole value: a multi-megabyte String is O(n) to inspect (cheap in
          # isolation, but on a fail-closed audit path we do not want to pay
          # for it), and a very deeply nested Array recurses #inspect into
          # SystemStackError. Slicing a String to CONTEXT_INSPECT_LIMIT before
          # #inspect is cheap regardless of the source String's total size;
          # Array/other values get a size/class summary instead of a full dump.
          # @api private
          def placeholder_for(value)
            case value
            when String then value[0, CONTEXT_INSPECT_LIMIT].inspect
            when Array then "#<Array size=#{value.size}>"
            else "#<#{value.class}>"
            end
          rescue StandardError, SystemStackError
            "<uninspectable>"
          end

          # A hostile `context: "token=sk-live-..."` must not land in the audit
          # log verbatim just because it took the placeholder path instead of
          # the structured-Hash path. Wild::Hooks::Audit::Sanitizer#sanitize_string
          # redacts `key=value`-shaped tokens out of free-form strings;
          # capability_gate already depends on ../hooks per package.yml.
          # @api private
          def sanitized_placeholder(value)
            Wild::Hooks::Audit::Sanitizer.new.sanitize_string(placeholder_for(value))
          rescue StandardError
            "<uninspectable>"
          end

          # Even a Hash that coerced cleanly can still be unsafe to write: NaN
          # floats and Infinity raise out of JSON generation by default,
          # invalid-encoding binary strings and self-referential structures do
          # too, and an oversized context blows past the audit_event.yml
          # `extra` budget (documented < 2 KiB). Replace it with a diagnosable
          # summary rather than losing the whole audit line at write time.
          # @api private
          def bound_context(hash)
            json = JSON.generate(hash, max_nesting: CONTEXT_JSON_MAX_NESTING)
            return hash if json.bytesize <= CONTEXT_JSON_BYTE_LIMIT

            truncated_summary(hash)
          rescue JSON::GeneratorError, JSON::NestingError, Encoding::UndefinedConversionError, SystemStackError
            truncated_summary(hash)
          end

          # @api private
          def truncated_summary(hash)
            { truncated: true, keys: hash.keys.first(CONTEXT_KEY_LIMIT).map(&:to_s) }
          rescue StandardError, SystemStackError
            { truncated: true, keys: [] }
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
