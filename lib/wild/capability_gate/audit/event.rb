# frozen_string_literal: true

require "time"
require "securerandom"

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
      class Event
        # The contract's outcome enum (audit_event.yml). `allowed`/`denied` from
        # the EvaluationResult map to the contract's `allow`/`deny`.
        VALID_OUTCOMES = %w[allow deny evaluation_error].freeze
        UNKNOWN_OUTCOME = "evaluation_error"

        attr_reader :timestamp, :decision_id, :subject, :capability, :risk_level,
                    :outcome, :reason, :rationale, :policy_version,
                    :prerequisites_checked, :prerequisites_passed, :session_id, :context

        # Build an audit event from an EvaluationResult and supplementary data.
        # This is the primary factory — ensures schema consistency.
        def self.from_evaluation(evaluation_result, registry:, session_id: nil, context: {})
          attrs = extract_attrs(evaluation_result, registry)
          new(**attrs, session_id: session_id, context: context)
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
          @context = Hash(context).freeze
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
        end
      end
    end
  end
end
