# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Models
        class TriageEntry
          SEVERITIES = %i[critical high medium low].freeze

          attr_reader :flake_record, :severity, :severity_score, :remediations, :trend

          def initialize(flake_record:, severity:, severity_score:, remediations: [], trend: :stable)
            raise ArgumentError, "flake_record must be a FlakeRecord" unless flake_record.is_a?(FlakeRecord)

            unless SEVERITIES.include?(severity.to_sym)
              raise ArgumentError, "severity must be one of #{SEVERITIES.inspect}, got: #{severity.inspect}"
            end

            @flake_record = flake_record
            @severity = severity.to_sym
            @severity_score = severity_score.to_f
            @remediations = Array(remediations).map(&:to_s).freeze
            @trend = trend.to_sym
          end

          delegate :test_identity, to: :flake_record

          def critical?
            severity == :critical
          end

          def high?
            severity == :high
          end

          def to_h
            {
              test_identity: test_identity.to_h,
              severity: severity,
              severity_score: severity_score,
              flake_rate: flake_record.flake_rate,
              failure_count: flake_record.failure_count,
              total_runs: flake_record.total_runs,
              trend: trend,
              root_causes: flake_record.root_causes.map(&:to_h),
              remediations: remediations
            }
          end
        end
      end
    end
  end
end
