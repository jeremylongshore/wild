# frozen_string_literal: true

require "time"

module Wild
  module Analyzers
    module Permission
      module Models
        class AuditReport
          attr_reader :findings, :coverage_reports, :generated_at

          def initialize(findings:, coverage_reports:, generated_at: Time.now.utc)
            @findings = findings.sort.freeze
            @coverage_reports = coverage_reports.freeze
            @generated_at = generated_at
          end

          def summary
            {
              total_findings: findings.size,
              by_severity: severity_counts,
              total_capabilities: coverage_reports.flat_map(&:granted_capabilities).uniq.size,
              total_callers: coverage_reports.map(&:caller_id).uniq.size,
              generated_at: generated_at.iso8601
            }
          end

          def findings_by_severity(severity)
            findings.select { |f| f.severity == severity.to_sym }
          end

          private

          def severity_counts
            Models::Finding::SEVERITIES.to_h { |sev| [sev, findings.count { |f| f.severity == sev }] } # rubocop:disable Rails/IndexWith
          end
        end
      end
    end
  end
end
