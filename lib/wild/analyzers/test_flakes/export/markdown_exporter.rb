# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Export
        class MarkdownExporter
          def export(triage_entries, title: "Flaky Test Triage Report", metadata: {})
            raise ExportError, "triage_entries must be an Array" unless triage_entries.is_a?(Array)

            sections = [
              render_header(title, metadata),
              render_summary(triage_entries),
              render_entries(triage_entries)
            ]

            sections.join("\n\n")
          end

          private

          def render_header(title, metadata)
            lines = ["# #{title}", "", "_Generated: #{Time.now.utc.strftime("%Y-%m-%d %H:%M UTC")}_"]
            metadata.each { |k, v| lines << "_#{k}: #{v}_" }
            lines.join("\n")
          end

          def render_summary(entries)
            by_severity = entries.group_by(&:severity)
            lines = ["## Summary", ""]
            lines << "| Severity | Count |"
            lines << "|----------|-------|"
            %i[critical high medium low].each do |sev|
              count = by_severity[sev]&.size || 0
              lines << "| #{sev.to_s.capitalize} | #{count} |"
            end
            lines << ""
            lines << "**Total flaky tests:** #{entries.size}"
            lines.join("\n")
          end

          def render_entries(entries)
            return "## Flaky Tests\n\n_No flaky tests detected._" if entries.empty?

            sections = ["## Flaky Tests"]
            entries.each_with_index do |entry, idx|
              sections << render_entry(entry, idx + 1)
            end
            sections.join("\n\n")
          end

          def render_entry(entry, index)
            record = entry.flake_record
            identity = record.test_identity
            lines = entry_header_lines(entry, index, record, identity)
            lines << ""
            lines << render_root_causes(record.root_causes)
            lines << ""
            lines << render_remediations(entry.remediations)
            lines.join("\n")
          end

          def entry_header_lines(entry, index, record, identity)
            lines = entry_title_lines(entry, index, identity)
            rate_pct = (record.flake_rate * 100).round(1)
            lines << "**Flake Rate:** #{rate_pct}% (#{record.failure_count}/#{record.total_runs} runs)"
            lines << "**Trend:** #{entry.trend}"
            lines
          end

          def entry_title_lines(entry, index, identity)
            lines = ["### #{index}. #{escape_md(identity.test_name)}", ""]
            lines << "**Severity:** #{entry.severity.to_s.upcase} (score: #{entry.severity_score})"
            lines << "**File:** `#{identity.file_path}`"
            lines << "**Context:** #{identity.context}" unless identity.context.empty?
            lines
          end

          def render_root_causes(causes)
            return "**Root Causes:** Unknown" if causes.empty?

            lines = ["**Root Causes:**", ""]
            causes.each do |rc|
              lines << "- `#{rc.category}` (confidence: #{(rc.confidence * 100).round}%)"
              lines << "  - #{rc.description}" if rc.description
            end
            lines.join("\n")
          end

          def render_remediations(remediations)
            return "" if remediations.empty?

            lines = ["**Suggested Remediations:**", ""]
            remediations.each { |r| lines << "- #{r}" }
            lines.join("\n")
          end

          # Escapes backslash AND pipe (block form avoids gsub replacement-string
          # backslash interpretation), then neutralizes backticks. Closes a
          # CodeQL rb/incomplete-sanitization finding carried in from the
          # wild-test-flake-forensics source — same fix as PR #25's permission
          # markdown exporter. Behavior-preserving for all existing inputs;
          # documented as a scope extension to the Role 5 PR-7 move.
          def escape_md(text)
            text.to_s.gsub(/[\\|]/) { |c| "\\#{c}" }.gsub("`", "'")
          end
        end
      end
    end
  end
end
