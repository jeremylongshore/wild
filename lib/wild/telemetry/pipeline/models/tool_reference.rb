# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Models
        class ToolReference
          VALID_ACTIONS = %i[called mentioned failed not_found].freeze
          VALID_OUTCOMES = %i[success error not_available].freeze

          attr_reader :name, :action, :outcome, :turn_index

          def initialize(name:, action:, turn_index:, outcome: nil)
            raise ArgumentError, "name must be a non-empty String" unless valid_string?(name)

            validate_action!(action)
            validate_outcome!(outcome) unless outcome.nil?
            raise ArgumentError, "turn_index must be a non-negative Integer" unless valid_index?(turn_index)

            @name = name.freeze
            @action = action.to_sym
            @outcome = outcome&.to_sym
            @turn_index = turn_index
          end

          def to_h
            {
              name: name,
              action: action,
              outcome: outcome,
              turn_index: turn_index
            }
          end

          private

          def valid_string?(value)
            value.is_a?(String) && !value.strip.empty?
          end

          def valid_index?(value)
            value.is_a?(Integer) && value >= 0
          end

          def validate_action!(action)
            sym = action.to_sym
            return if VALID_ACTIONS.include?(sym)

            raise ArgumentError, "action must be one of #{VALID_ACTIONS.inspect}, got: #{action.inspect}"
          end

          def validate_outcome!(outcome)
            sym = outcome.to_sym
            return if VALID_OUTCOMES.include?(sym)

            raise ArgumentError, "outcome must be one of #{VALID_OUTCOMES.inspect}, got: #{outcome.inspect}"
          end
        end
      end
    end
  end
end
