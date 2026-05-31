# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class Gap
          VALID_TYPES = %i[denial failure latency utilization coverage pattern].freeze

          attr_reader :type, :action, :severity, :evidence, :description, :recommendation

          # rubocop:disable Metrics/ParameterLists
          def initialize(type:, action:, severity:, evidence:, description:, recommendation: nil)
            @type = type.to_sym
            @action = action.to_s
            @severity = severity.to_f
            @evidence = evidence
            @description = description.to_s
            @recommendation = recommendation

            validate!
          end
          # rubocop:enable Metrics/ParameterLists

          def to_h
            {
              type: type,
              action: action,
              severity: severity,
              evidence: evidence,
              description: description,
              recommendation: recommendation
            }
          end

          def <=>(other)
            other.severity <=> severity
          end

          include Comparable

          private

          def validate!
            unless VALID_TYPES.include?(type)
              raise ValidationError, "invalid gap type: #{type.inspect}. Must be one of #{VALID_TYPES.inspect}"
            end

            return if severity.between?(0.0, 1.0)

            raise ValidationError, "severity must be between 0.0 and 1.0, got #{severity}"
          end
        end
      end
    end
  end
end
