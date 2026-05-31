# frozen_string_literal: true

require "json"

module Wild
  module Telemetry
    module Pipeline
      module Export
        class JsonExporter
          def export(transcripts, metadata: {})
            raise ExportError, "transcripts must be an Array" unless transcripts.is_a?(Array)

            payload = build_payload(transcripts, metadata)
            JSON.generate(payload)
          rescue JSON::GeneratorError => e
            raise ExportError, "JSON generation failed: #{e.message}"
          end

          def export_batch(batch, metadata: {})
            raise ExportError, "batch must be a TranscriptBatch" unless batch.is_a?(Models::TranscriptBatch)

            export(batch.transcripts, metadata: batch.metadata.merge(metadata))
          end

          private

          def build_payload(transcripts, metadata)
            {
              metadata: base_metadata.merge(metadata),
              summary: build_summary(transcripts),
              transcripts: transcripts.map(&:to_h)
            }
          end

          def base_metadata
            {
              generated_at: Time.now.utc.iso8601,
              version: Wild::VERSION,
              schema_version: "1.0"
            }
          end

          def build_summary(transcripts)
            {
              transcript_count: transcripts.size,
              total_turns: transcripts.sum(&:turn_count),
              total_intents: transcripts.sum(&:intent_count),
              total_tool_references: transcripts.sum(&:tool_reference_count),
              source_types: transcripts.map(&:source_type).uniq
            }
          end
        end
      end
    end
  end
end
