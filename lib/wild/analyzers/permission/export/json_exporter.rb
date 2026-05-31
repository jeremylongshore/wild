# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Analyzers
    module Permission
      module Export
        class JsonExporter
          def export(audit_report)
            unless audit_report.is_a?(Models::AuditReport)
              raise ExportError, "Expected AuditReport, got #{audit_report.class}"
            end

            JSON.generate(serialize(audit_report))
          end

          private

          def serialize(report)
            {
              generated_at: report.generated_at.iso8601,
              summary: report.summary,
              findings: report.findings.map { |f| serialize_finding(f) },
              coverage_reports: report.coverage_reports.map { |r| serialize_coverage(r) }
            }
          end

          def serialize_finding(finding)
            {
              type: finding.type,
              severity: finding.severity,
              message: finding.message,
              evidence: finding.evidence
            }
          end

          def serialize_coverage(coverage)
            {
              caller_id: coverage.caller_id,
              granted_capabilities: coverage.granted_capabilities,
              denied_capabilities: coverage.denied_capabilities,
              coverage_ratio: coverage.coverage_ratio.round(4)
            }
          end
        end
      end
    end
  end
end
