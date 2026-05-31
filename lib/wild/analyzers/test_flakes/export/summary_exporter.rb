# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Export
        class SummaryExporter
          def export(triage_entries)
            raise ExportError, "triage_entries must be an Array" unless triage_entries.is_a?(Array)

            return "No flaky tests detected.\n" if triage_entries.empty?

            lines = [header(triage_entries)]
            triage_entries.each { |entry| lines << format_entry(entry) }
            "#{lines.join("\n")}\n"
          end

          private

          def header(entries)
            total = entries.size
            critical = entries.count(&:critical?)
            high = entries.count(&:high?)
            "FLAKE REPORT: #{total} flaky test(s) — #{critical} critical, #{high} high"
          end

          def format_entry(entry)
            record = entry.flake_record
            identity = record.test_identity
            cause = primary_cause_label(record)
            rate_pct = (record.flake_rate * 100).round(1)

            "[#{entry.severity.to_s.upcase}] #{truncate(identity.test_name, 60)} " \
              "(#{rate_pct}% flake, #{cause})"
          end

          def primary_cause_label(record)
            cause = record.primary_root_cause
            return "cause: unknown" unless cause

            "cause: #{cause.category}"
          end

          def truncate(str, max_len)
            return str if str.length <= max_len

            "#{str[0, max_len - 3]}..."
          end
        end
      end
    end
  end
end
