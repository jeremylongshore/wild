# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Export
        class MarkdownExporter
          SEVERITY_LABELS = {
            (0.7..1.0) => "HIGH",
            (0.4...0.7) => "MEDIUM",
            (0.0...0.4) => "LOW"
          }.freeze

          # Returns a Markdown string for the given GapReport.
          def export(report)
            lines = []
            lines << "# Gap Analysis Report"
            lines << ""
            lines << "Generated: #{report.generated_at}"
            lines << ""
            lines << build_summary_section(report)
            lines << ""
            lines << build_gaps_section(report)
            lines.join("\n")
          end

          # Writes Markdown to path and returns path.
          def write(report, path)
            content = export(report)
            File.write(path, content)
            path
          end

          private

          def build_summary_section(report)
            summary = report.summary
            lines = ["## Summary", ""]
            lines.concat(summary_stats_lines(summary))
            lines << ""
            lines.concat(by_type_lines(summary))
            lines.concat(top_actions_lines(summary))
            lines.join("\n")
          end

          def summary_stats_lines(summary)
            [
              "- **Total Gaps**: #{summary[:total_gaps]}",
              "- **High Severity**: #{summary[:high_severity_count]}",
              "- **Average Severity**: #{summary[:severity_avg]}"
            ]
          end

          def by_type_lines(summary)
            lines = ["### By Type", ""]
            summary[:by_type].each { |type, count| lines << "- #{type}: #{count}" }
            lines << ""
            lines
          end

          def top_actions_lines(summary)
            return [] if summary[:top_actions].empty?

            lines = ["### Top Actions by Max Severity", ""]
            summary[:top_actions].each do |entry|
              lines << "- `#{entry[:action]}` — #{entry[:max_severity].round(3)}"
            end
            lines
          end

          def build_gaps_section(report)
            return "## Gaps\n\n_No gaps detected._" if report.gaps.empty?

            lines = ["## Gaps", ""]
            report.gaps.each_with_index do |gap, idx|
              lines << build_gap_entry(gap, idx + 1)
              lines << ""
            end
            lines.join("\n")
          end

          def build_gap_entry(gap, number)
            level = severity_level(gap.severity)
            lines = ["### #{number}. [#{level}] #{gap.action} (#{gap.type})", ""]
            lines << "**Severity**: #{gap.severity.round(3)}"
            lines << ""
            lines << gap.description
            lines << ""
            lines.concat(recommendation_lines(gap))
            lines.concat(evidence_lines(gap))
            lines.join("\n")
          end

          def recommendation_lines(gap)
            return [] unless gap.recommendation

            ["**Recommendation**: #{gap.recommendation}", ""]
          end

          def evidence_lines(gap)
            lines = ["**Evidence**:", ""]
            gap.evidence.each { |key, value| lines << "- `#{key}`: #{value}" }
            lines
          end

          def severity_level(severity)
            SEVERITY_LABELS.each do |range, label|
              return label if range.cover?(severity)
            end
            "LOW"
          end
        end
      end
    end
  end
end
