# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Models
        class Transcript
          attr_reader :source_type, :source_id, :turns, :intents, :tool_references, :metadata, :created_at

          # rubocop:disable Metrics/ParameterLists
          def initialize(source_type:, source_id:, turns: [], intents: [], tool_references: [], metadata: {},
                         created_at: nil)
            validate!(source_type, source_id, turns, intents, tool_references, metadata)
            assign!(source_type, source_id, turns, intents, tool_references, metadata, created_at)
          end
          # rubocop:enable Metrics/ParameterLists

          def turn_count
            turns.size
          end

          def intent_count
            intents.size
          end

          def tool_reference_count
            tool_references.size
          end

          def to_h
            {
              source_type: source_type,
              source_id: source_id,
              created_at: created_at.iso8601,
              turn_count: turn_count,
              intent_count: intent_count,
              tool_reference_count: tool_reference_count,
              turns: turns.map(&:to_h),
              intents: intents.map(&:to_h),
              tool_references: tool_references.map(&:to_h),
              metadata: metadata
            }
          end

          private

          # rubocop:disable Metrics/ParameterLists -- 6-field domain value object
          def validate!(source_type, source_id, turns, intents, tool_references, metadata)
            raise ArgumentError, "source_type must be a Symbol" unless source_type.is_a?(Symbol)
            raise ArgumentError, "source_id must be a non-empty String" unless valid_string?(source_id)
            raise ArgumentError, "turns must be an Array" unless turns.is_a?(Array)
            raise ArgumentError, "intents must be an Array" unless intents.is_a?(Array)
            raise ArgumentError, "tool_references must be an Array" unless tool_references.is_a?(Array)
            raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)
          end
          # rubocop:enable Metrics/ParameterLists

          # rubocop:disable Metrics/ParameterLists -- 7-field domain value object
          def assign!(source_type, source_id, turns, intents, tool_references, metadata, created_at)
            @source_type = source_type
            @source_id = source_id.freeze
            @turns = turns.freeze
            @intents = intents.freeze
            @tool_references = tool_references.freeze
            @metadata = metadata.freeze
            @created_at = created_at || Time.now.utc
          end
          # rubocop:enable Metrics/ParameterLists

          def valid_string?(value)
            value.is_a?(String) && !value.strip.empty?
          end
        end
      end
    end
  end
end
