# frozen_string_literal: true

module Wild
  module CapabilityGate
    module Prerequisites
      # Immutable result of evaluating one or more prerequisites.
      #
      # Used internally by the Checker to communicate results back to the
      # Evaluator. Carries the list of prerequisite types that were checked
      # and, on failure, human-readable details about which prerequisite failed.
      class CheckResult
        attr_reader :checked_types, :details

        def self.passed(checked_types: [])
          new(true, checked_types: checked_types)
        end

        def self.failed(checked_types: [], details: nil)
          new(false, checked_types: checked_types, details: details)
        end

        def satisfied?
          @satisfied
        end

        private

        def initialize(satisfied, checked_types: [], details: nil)
          @satisfied = satisfied
          @checked_types = Array(checked_types).freeze
          @details = details
          freeze
        end
      end
    end
  end
end
