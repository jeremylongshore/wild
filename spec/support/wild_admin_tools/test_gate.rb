# frozen_string_literal: true

module Wild
  module AdminTools
    module TestSupport
      class TestGate
        attr_accessor :default_result, :results

        def initialize(default_allowed: true)
          @default_result = default_allowed
          @results = {}
          @calls = []
        end

        def evaluate(caller:, capability:, context: {})
          @calls << { caller: caller, capability: capability, context: context }

          specific = @results[capability.to_sym] || @results[capability.to_s]
          return specific if specific

          if @default_result
            TestEvaluationResult.allowed(capability_name: capability.to_sym, caller_id: caller.to_s)
          else
            TestEvaluationResult.denied(
              capability_name: capability.to_sym,
              caller_id: caller.to_s,
              reason: :not_granted
            )
          end
        end

        def calls
          @calls.dup
        end

        def deny_capability(capability, reason: :not_granted, details: nil)
          @results[capability.to_sym] = TestEvaluationResult.denied(
            capability_name: capability.to_sym,
            caller_id: "test",
            reason: reason,
            details: details
          )
        end

        def allow_capability(capability)
          @results[capability.to_sym] = TestEvaluationResult.allowed(
            capability_name: capability.to_sym,
            caller_id: "test"
          )
        end

        def reset!
          @calls.clear
          @results.clear
        end
      end

      class TestEvaluationResult
        attr_reader :capability_name, :caller_id, :reason, :details

        def self.allowed(capability_name:, caller_id:)
          new(allowed: true, capability_name: capability_name, caller_id: caller_id)
        end

        def self.denied(capability_name:, caller_id:, reason:, details: nil)
          new(
            allowed: false, capability_name: capability_name,
            caller_id: caller_id, reason: reason, details: details
          )
        end

        def initialize(allowed:, capability_name:, caller_id:, reason: nil, details: nil)
          @allowed = allowed
          @capability_name = capability_name
          @caller_id = caller_id
          @reason = reason
          @details = details
        end

        def allowed?
          @allowed
        end

        def denied?
          !@allowed
        end
      end
    end
  end
end
