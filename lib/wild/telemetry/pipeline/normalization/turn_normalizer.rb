# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Normalization
        class TurnNormalizer
          def normalize(turns, config: Wild.config.telemetry.pipeline)
            raise NormalizationError, "turns must be an Array" unless turns.is_a?(Array)

            limited = apply_turn_limit(turns, config.max_turns_per_transcript)
            limited.map { |turn| normalize_turn(turn, config) }
          end

          private

          def apply_turn_limit(turns, max)
            return turns if turns.size <= max

            turns.first(max)
          end

          def normalize_turn(turn, config)
            normalized_content = truncate_content(turn.content, config.max_turn_content_length)

            Models::Turn.new(
              role: turn.role,
              content: normalized_content,
              timestamp: turn.timestamp,
              metadata: turn.metadata
            )
          end

          def truncate_content(content, max_length)
            return content if content.length <= max_length

            content[0, max_length]
          end
        end
      end
    end
  end
end
