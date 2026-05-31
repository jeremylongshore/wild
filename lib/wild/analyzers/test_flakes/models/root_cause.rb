# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Models
        class RootCause
          CATEGORIES = %i[
            timing_dependent
            order_dependent
            shared_state
            external_dependency
            random_seed
            resource_contention
            timezone_locale
            unknown
          ].freeze

          attr_reader :category, :confidence, :evidence, :description

          def initialize(category:, confidence:, evidence: [], description: nil)
            validate_category!(category)
            validate_confidence!(confidence)

            @category = category.to_sym
            @confidence = confidence.to_f
            @evidence = Array(evidence).map(&:to_s).freeze
            @description = description&.to_s&.freeze
          end

          def to_h
            {
              category: category,
              confidence: confidence,
              evidence: evidence,
              description: description
            }
          end

          def high_confidence?
            confidence >= 0.7
          end

          def medium_confidence?
            confidence >= 0.4 && confidence < 0.7
          end

          def low_confidence?
            confidence < 0.4
          end

          private

          def validate_category!(category)
            sym = category.to_sym
            return if CATEGORIES.include?(sym)

            raise ArgumentError, "category must be one of #{CATEGORIES.inspect}, got: #{category.inspect}"
          end

          def validate_confidence!(confidence)
            f = confidence.to_f
            return if f.between?(0.0, 1.0)

            raise ArgumentError, "confidence must be between 0.0 and 1.0, got: #{confidence.inspect}"
          end
        end
      end
    end
  end
end
