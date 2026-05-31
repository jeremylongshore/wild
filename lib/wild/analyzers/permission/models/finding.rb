# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Models
        class Finding
          SEVERITIES = %i[info warning error critical].freeze
          SEVERITY_RANKS = { info: 0, warning: 1, error: 2, critical: 3 }.freeze

          attr_reader :type, :severity, :message, :evidence

          def initialize(type:, severity:, message:, evidence: {})
            validate_severity!(severity)
            @type = type.to_sym
            @severity = severity.to_sym
            @message = message
            @evidence = (evidence || {}).freeze
          end

          def <=>(other)
            SEVERITY_RANKS[other.severity] <=> SEVERITY_RANKS[severity]
          end

          include Comparable

          private

          def validate_severity!(severity)
            sym = severity.to_sym
            return if SEVERITIES.include?(sym)

            raise ArgumentError, "Invalid severity #{severity.inspect}. Must be one of #{SEVERITIES.inspect}"
          end
        end
      end
    end
  end
end
