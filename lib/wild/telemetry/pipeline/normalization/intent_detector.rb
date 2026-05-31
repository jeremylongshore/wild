# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Normalization
        class IntentDetector
          INTENT_PATTERNS = [
            { pattern: /\bI need to\b/i, description: "Expressed need", base_confidence: 0.65 },
            { pattern: /\bI want to\b/i, description: "Expressed want", base_confidence: 0.60 },
            { pattern: /\bLet me\b/i, description: "Initiating action", base_confidence: 0.55 },
            { pattern: /\bLet me try\b/i, description: "Attempting action", base_confidence: 0.65 },
            { pattern: /\bI('ll| will)\b/i, description: "Declared action", base_confidence: 0.60 },
            { pattern: /\bI('m| am) going to\b/i, description: "Planned action", base_confidence: 0.70 },
            { pattern: /\bI can't find a tool for\b/i, description: "Missing capability", base_confidence: 0.85 },
            { pattern: /\bThere's no way to\b/i, description: "Identified limitation", base_confidence: 0.80 },
            { pattern: /\bI don't have (a |the )?tool\b/i, description: "Missing tool", base_confidence: 0.85 },
            { pattern: /\bI cannot\b/i, description: "Stated inability", base_confidence: 0.70 },
            { pattern: /\bHere's (how|what)\b/i, description: "Providing explanation", base_confidence: 0.55 },
            { pattern: /\bTo (do|accomplish|complete|fix)\b/i, description: "Goal statement", base_confidence: 0.60 }
          ].freeze

          TOOL_CALL_PATTERN = /\[?(tool_use|tool_call|function_call|mcp:request)\]?/i

          def detect(turns, config: Wild.config.telemetry.pipeline)
            raise NormalizationError, "turns must be an Array" unless turns.is_a?(Array)

            threshold = config.intent_confidence_threshold
            intents = []

            turns.each_with_index do |turn, index|
              next unless turn.assistant_turn? || turn.user_turn?

              extract_intents(turn, index, threshold).each { |intent| intents << intent }
            end

            intents
          end

          private

          def extract_intents(turn, index, threshold)
            return [] if turn.content.strip.empty? || tool_content?(turn.content)

            matched = matching_intents(turn.content, index, threshold)
            best = matched.max_by(&:confidence)
            best ? [best] : []
          end

          def matching_intents(content, index, threshold)
            INTENT_PATTERNS.filter_map do |spec|
              next unless content.match?(spec[:pattern])

              confidence = compute_confidence(content, spec)
              next if confidence < threshold

              build_intent(content, spec, confidence, index)
            end
          end

          def build_intent(content, spec, confidence, index)
            Models::Intent.new(
              description: build_description(content, spec),
              confidence: confidence,
              source_turn_index: index
            )
          end

          def tool_content?(content)
            content.match?(TOOL_CALL_PATTERN)
          end

          def build_description(content, spec)
            snippet = content.split(/[.!?\n]/).first(2).join(" ").strip
            snippet = snippet[0, 80] if snippet.length > 80
            snippet.empty? ? spec[:description] : snippet
          end

          def compute_confidence(content, spec)
            base = spec[:base_confidence]
            length_factor = content.length > 200 ? 0.05 : 0.0
            [base + length_factor, 1.0].min
          end
        end
      end
    end
  end
end
