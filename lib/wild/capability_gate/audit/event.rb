# frozen_string_literal: true

require "time"

module Wild
  module CapabilityGate
    module Audit
      # Immutable audit event produced by every capability evaluation.
      #
      # Schema matches 002-AT-STND-capability-model.md Section 8.
      # Every evaluation — allowed, denied, or errored — must produce one of these.
      # See 003-TQ-STND-governance-model.md Section 5 (audit completeness rule).
      class Event
        VALID_RESULTS = %w[allowed denied].freeze

        attr_reader :timestamp, :caller_id, :capability, :risk_level,
                    :result, :reason, :prerequisites_checked,
                    :prerequisites_passed, :session_id, :context

        # Build an audit event from an EvaluationResult and supplementary data.
        # This is the primary factory — ensures schema consistency.
        def self.from_evaluation(evaluation_result, registry:, session_id: nil, context: {})
          attrs = extract_attrs(evaluation_result, registry)
          new(**attrs, session_id: session_id, context: context)
        end

        # rubocop:disable Metrics/ParameterLists -- value object with 10-field schema from Doc 002 Section 8
        def initialize(timestamp:, caller_id:, capability:, risk_level:, result:,
                       reason: nil, prerequisites_checked: [], prerequisites_passed: true,
                       session_id: nil, context: {})
          # rubocop:enable Metrics/ParameterLists
          @timestamp = timestamp
          @caller_id = String(caller_id)
          @capability = String(capability)
          @risk_level = String(risk_level)
          @result = validate_result(result)
          @reason = reason
          @prerequisites_checked = Array(prerequisites_checked).freeze
          @prerequisites_passed = prerequisites_passed
          @session_id = session_id
          @context = Hash(context).freeze
          freeze
        end

        # Serialize to the JSON-compatible hash matching Doc 002 Section 8.
        def to_h
          build_hash
        end

        private

        def build_hash
          { "event" => "capability_evaluation",
            "timestamp" => @timestamp.utc.iso8601(3),
            "caller_id" => @caller_id, "capability" => @capability,
            "risk_level" => @risk_level, "result" => @result,
            "reason" => @reason,
            "prerequisites_checked" => @prerequisites_checked,
            "prerequisites_passed" => @prerequisites_passed,
            "session_id" => @session_id, "context" => @context }
        end

        def validate_result(result)
          result_str = String(result)
          return result_str if VALID_RESULTS.include?(result_str)

          raise ArgumentError, "invalid result #{result.inspect}, must be one of: #{VALID_RESULTS.join(", ")}"
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
              caller_id: evaluation_result.caller_id,
              capability: capability_name.to_s,
              risk_level: resolve_risk_level(capability_name, registry),
              result: evaluation_result.allowed? ? "allowed" : "denied",
              reason: evaluation_result.reason&.to_s }
          end

          def prerequisite_attrs(evaluation_result)
            { prerequisites_checked: evaluation_result.prerequisites_checked.map(&:to_s),
              prerequisites_passed: evaluation_result.allowed? || !prerequisite_failure?(evaluation_result) }
          end

          def resolve_risk_level(capability_name, registry)
            cap = registry.find(capability_name)
            cap ? cap.risk_level.to_s : "unknown"
          end

          def prerequisite_failure?(evaluation_result)
            evaluation_result.denied? && evaluation_result.reason == :prerequisite_not_met
          end
        end
      end
    end
  end
end
