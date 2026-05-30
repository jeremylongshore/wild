# frozen_string_literal: true

module Wild
  module CapabilityGate
    module Prerequisites
      # Evaluates all prerequisites for a capability.
      #
      # Dispatches each prerequisite to its type-specific checker.
      # All prerequisites must pass for the result to be satisfied.
      # Evaluation stops at the first failure (short-circuit).
      #
      # Fail-closed: unknown prerequisite types result in failure.
      # New types are added by registering a checker in CHECKERS.
      class Checker
        CHECKERS = {
          file_exists: FileExistsChecker,
          config_value: ConfigValueChecker
        }.freeze

        def initialize(context: {})
          @context = context
        end

        # Check all prerequisites. Returns a CheckResult.
        # Short-circuits on first failure.
        def check_all(prerequisites)
          checked_types = []

          prerequisites.each do |prereq|
            checked_types << prereq.type
            result = check_one(prereq)
            return CheckResult.failed(checked_types: checked_types, details: result.details) unless result.satisfied?
          end

          CheckResult.passed(checked_types: checked_types)
        end

        private

        def check_one(prereq)
          checker = CHECKERS[prereq.type]

          unless checker
            return CheckResult.failed(
              details: "no checker registered for prerequisite type: #{prereq.type.inspect}"
            )
          end

          checker.check(prereq, context: @context)
        end
      end
    end
  end
end
