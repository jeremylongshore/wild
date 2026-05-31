# frozen_string_literal: true

require "json"

module Wild
  module Analyzers
    module TestFlakes
      module Export
        class JsonExporter
          def export(triage_entries, metadata: {})
            raise ExportError, "triage_entries must be an Array" unless triage_entries.is_a?(Array)

            payload = build_payload(triage_entries, metadata)
            JSON.generate(payload)
          rescue JSON::GeneratorError => e
            raise ExportError, "JSON generation failed: #{e.message}"
          end

          private

          def build_payload(entries, metadata)
            {
              metadata: base_metadata.merge(metadata),
              summary: build_summary(entries),
              flakes: entries.map(&:to_h)
            }
          end

          def base_metadata
            {
              generated_at: Time.now.utc.iso8601,
              # F1 — one gem-level version constant; the old
              # WildTestFlakeForensics::VERSION was deleted in the move.
              version: Wild::VERSION,
              total_flakes: nil
            }
          end

          def build_summary(entries)
            severity_counts = severity_breakdown(entries)
            severity_counts.merge(
              total: entries.size,
              avg_flake_rate: avg_flake_rate(entries),
              top_root_cause: top_root_cause(entries)
            )
          end

          def severity_breakdown(entries)
            by_severity = entries.group_by(&:severity)
            Models::TriageEntry::SEVERITIES.index_with do |sev|
              by_severity[sev]&.size || 0
            end
          end

          def avg_flake_rate(entries)
            return 0.0 if entries.empty?

            rates = entries.map { |e| e.flake_record.flake_rate }
            (rates.sum / rates.size).round(4)
          end

          def top_root_cause(entries)
            return nil if entries.empty?

            all_causes = entries.flat_map { |e| e.flake_record.root_causes }
            return nil if all_causes.empty?

            all_causes.max_by(&:confidence)&.category
          end
        end
      end
    end
  end
end
