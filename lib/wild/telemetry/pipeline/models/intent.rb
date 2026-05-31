# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Models
        class Intent
          attr_reader :description, :confidence, :source_turn_index

          def initialize(description:, confidence:, source_turn_index:)
            raise ArgumentError, "description must be a non-empty String" unless valid_string?(description)

            validate_confidence!(confidence)
            validate_turn_index!(source_turn_index)

            @description = description.freeze
            @confidence = confidence.to_f
            @source_turn_index = source_turn_index
          end

          def to_h
            {
              description: description,
              confidence: confidence,
              source_turn_index: source_turn_index
            }
          end

          private

          def valid_string?(value)
            value.is_a?(String) && !value.strip.empty?
          end

          def validate_confidence!(value)
            return if value.is_a?(Numeric) && value >= 0.0 && value <= 1.0

            raise ArgumentError, "confidence must be between 0.0 and 1.0, got: #{value.inspect}"
          end

          def validate_turn_index!(value)
            return if value.is_a?(Integer) && value >= 0

            raise ArgumentError, "source_turn_index must be a non-negative Integer, got: #{value.inspect}"
          end
        end
      end
    end
  end
end
