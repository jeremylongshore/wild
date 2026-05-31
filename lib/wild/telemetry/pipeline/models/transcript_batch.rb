# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Models
        class TranscriptBatch
          attr_reader :transcripts, :metadata, :created_at

          def initialize(transcripts: [], metadata: {}, created_at: nil)
            raise ArgumentError, "transcripts must be an Array" unless transcripts.is_a?(Array)
            raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)

            @transcripts = transcripts.freeze
            @metadata = metadata.freeze
            @created_at = created_at || Time.now.utc
          end

          delegate :size, to: :transcripts

          delegate :empty?, to: :transcripts

          def total_turns
            transcripts.sum(&:turn_count)
          end

          def total_intents
            transcripts.sum(&:intent_count)
          end

          def total_tool_references
            transcripts.sum(&:tool_reference_count)
          end

          def source_types
            transcripts.map(&:source_type).uniq
          end

          def to_h
            {
              created_at: created_at.iso8601,
              transcript_count: size,
              total_turns: total_turns,
              total_intents: total_intents,
              total_tool_references: total_tool_references,
              source_types: source_types,
              metadata: metadata,
              transcripts: transcripts.map(&:to_h)
            }
          end
        end
      end
    end
  end
end
