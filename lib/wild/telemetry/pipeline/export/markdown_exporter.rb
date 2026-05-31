# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Export
        class MarkdownExporter
          ROLE_LABELS = {
            user: "User",
            assistant: "Assistant",
            system: "System",
            tool: "Tool"
          }.freeze

          def export(transcripts, metadata: {})
            raise ExportError, "transcripts must be an Array" unless transcripts.is_a?(Array)

            lines = build_header(transcripts, metadata)
            append_body(lines, transcripts)
            lines.flatten.join("\n")
          end

          private

          def build_header(transcripts, metadata)
            ["# Transcript Export", "", build_header_metadata(transcripts, metadata), "", "---", ""]
          end

          def append_body(lines, transcripts)
            if transcripts.empty?
              lines << "_No transcripts found._"
            else
              transcripts.each_with_index do |transcript, idx|
                lines << build_transcript_section(transcript, idx + 1)
                lines << ""
              end
            end
          end

          def build_header_metadata(transcripts, metadata)
            [
              "**Generated:** #{Time.now.utc.iso8601}",
              "**Transcripts:** #{transcripts.size}",
              "**Total Turns:** #{transcripts.sum(&:turn_count)}",
              metadata.any? ? "**Metadata:** #{metadata.map { |k, v| "#{k}=#{v}" }.join(", ")}" : nil
            ].compact
          end

          def build_transcript_section(transcript, number)
            lines = build_transcript_header(transcript, number)
            append_intents(lines, transcript)
            append_tool_references(lines, transcript)
            append_turns(lines, transcript)
            lines
          end

          def build_transcript_header(transcript, number)
            [
              "## Transcript #{number}: `#{transcript.source_id}`",
              "",
              "- **Source Type:** #{transcript.source_type}",
              "- **Created:** #{transcript.created_at.iso8601}",
              "- **Turns:** #{transcript.turn_count}",
              "- **Intents:** #{transcript.intent_count}",
              "- **Tool References:** #{transcript.tool_reference_count}",
              ""
            ]
          end

          def append_intents(lines, transcript)
            return unless transcript.intents.any?

            lines << "### Detected Intents"
            lines << ""
            transcript.intents.each do |intent|
              lines << "- (#{format("%.2f", intent.confidence)}) #{intent.description}"
            end
            lines << ""
          end

          def append_tool_references(lines, transcript)
            return unless transcript.tool_references.any?

            lines << "### Tool References"
            lines << ""
            transcript.tool_references.each do |ref|
              outcome_str = ref.outcome ? " -> #{ref.outcome}" : ""
              lines << "- `#{ref.name}` (#{ref.action}#{outcome_str}) at turn #{ref.turn_index}"
            end
            lines << ""
          end

          def append_turns(lines, transcript)
            lines << "### Turns"
            lines << ""
            transcript.turns.each_with_index { |turn, idx| lines << build_turn_block(turn, idx) }
          end

          def build_turn_block(turn, index)
            label = ROLE_LABELS[turn.role] || turn.role.to_s.capitalize
            ts = turn.timestamp ? " _(#{turn.timestamp.iso8601})_" : ""
            [
              "**[#{index}] #{label}**#{ts}",
              "",
              turn.content.empty? ? "_empty_" : turn.content,
              ""
            ]
          end
        end
      end
    end
  end
end
