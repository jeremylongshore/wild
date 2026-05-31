# frozen_string_literal: true

require "time"

module Wild
  module Analyzers
    module Permission
      module Export
        class MarkdownExporter
          SEVERITY_ICONS = { critical: "CRITICAL", error: "ERROR", warning: "WARN", info: "INFO" }.freeze

          def export(audit_report)
            unless audit_report.is_a?(Models::AuditReport)
              raise ExportError, "Expected AuditReport, got #{audit_report.class}"
            end

            sections = [
              header(audit_report),
              summary_table(audit_report),
              findings_section(audit_report),
              coverage_section(audit_report)
            ]
            sections.join("\n\n")
          end

          private

          def header(report)
            "# Permission Audit Report\n\nGenerated: #{report.generated_at.iso8601}"
          end

          def summary_table(report)
            s = report.summary
            lines = [
              "## Summary",
              "",
              "| Metric | Value |",
              "|--------|-------|",
              "| Total Findings | #{s[:total_findings]} |",
              "| Critical | #{s[:by_severity][:critical]} |",
              "| Error | #{s[:by_severity][:error]} |",
              "| Warning | #{s[:by_severity][:warning]} |",
              "| Info | #{s[:by_severity][:info]} |",
              "| Total Callers | #{s[:total_callers]} |"
            ]
            lines.join("\n")
          end

          def findings_section(report)
            return "## Findings\n\nNo findings." if report.findings.empty?

            rows = report.findings.map { |f| finding_row(f) }
            [
              "## Findings",
              "",
              "| Severity | Type | Message |",
              "|----------|------|---------|",
              *rows
            ].join("\n")
          end

          def finding_row(finding)
            icon = SEVERITY_ICONS[finding.severity] || finding.severity.to_s.upcase
            msg = escape_md(finding.message)
            "| #{icon} | `#{finding.type}` | #{msg} |"
          end

          def coverage_section(report)
            return "## Coverage\n\nNo coverage data." if report.coverage_reports.empty?

            rows = report.coverage_reports.map { |r| coverage_row(r) }
            [
              "## Coverage by Caller",
              "",
              "| Caller | Granted | Denied | Coverage |",
              "|--------|---------|--------|----------|",
              *rows
            ].join("\n")
          end

          def coverage_row(coverage)
            pct = (coverage.coverage_ratio * 100).round(1)
            "| `#{escape_md(coverage.caller_id)}` | #{coverage.granted_capabilities.size} | " \
              "#{coverage.denied_capabilities.size} | #{pct}% |"
          end

          def escape_md(text)
            text.to_s.gsub("|", '\\|').gsub("`", "'")
          end
        end
      end
    end
  end
end
