# frozen_string_literal: true

module Wild
  module Telemetry
    module Pipeline
      module Normalization
        class ToolExtractor
          MCP_REF_PATTERN = %r{mcp://([a-z_][a-z0-9_-]*)}i
          TOOL_USE_PATTERN = /\[tool_use\]\s*([a-z_][a-z0-9_-]*)/i
          TOOL_RESULT_PATTERN = /\[tool_result:([a-z_][a-z0-9_-]*)\]/i
          MCP_REQUEST_PATTERN = %r{\[mcp:request\]\s+tools/call\s+([a-z_][a-z0-9_-]*)}i
          MCP_RESULT_PATTERN = /\[mcp:result\]/i
          MCP_ERROR_PATTERN = /\[mcp:error\]/i
          CANT_FIND_TOOL_PATTERN = /I can't find a tool for|I don't have (a |the )?tool|There's no way to/i
          EXPLICIT_TOOL_CALL_PATTERN = /\b([a-z_][a-z0-9_]*)\s*\(\{/

          def extract(turns)
            raise NormalizationError, "turns must be an Array" unless turns.is_a?(Array)

            refs = []
            turns.each_with_index do |turn, index|
              extract_from_turn(turn, index).each { |ref| refs << ref }
            end
            refs
          end

          private

          # rubocop:disable Metrics/AbcSize
          def extract_from_turn(turn, index)
            content = turn.content
            refs = []

            refs.concat(extract_mcp_references(content, index, turn.metadata))
            refs.concat(extract_tool_use_blocks(content, index))
            refs.concat(extract_tool_results(content, index))
            refs.concat(extract_cant_find_references(content, index))
            refs.concat(extract_explicit_calls(content, index)) if refs.empty? && turn.assistant_turn?

            refs.uniq { |r| [r.name, r.action, r.turn_index] }
          end
          # rubocop:enable Metrics/AbcSize

          def extract_mcp_references(content, index, metadata)
            refs = []
            refs.concat(extract_mcp_request(content, index))
            refs.concat(extract_mcp_result(content, index, metadata))
            refs.concat(extract_mcp_error(content, index, metadata))
            refs.concat(extract_mcp_uris(content, index))
            refs
          end

          def extract_mcp_request(content, index)
            return [] unless content.match?(MCP_REQUEST_PATTERN)

            name = content.match(MCP_REQUEST_PATTERN)[1]
            [build_ref(name: name, action: :called, turn_index: index)]
          end

          def extract_mcp_result(content, index, metadata)
            return [] unless content.match?(MCP_RESULT_PATTERN)

            tool_name = metadata[:tool_name] || "unknown_tool"
            [build_ref(name: tool_name, action: :called, outcome: :success, turn_index: index)]
          end

          def extract_mcp_error(content, index, metadata)
            return [] unless content.match?(MCP_ERROR_PATTERN)

            tool_name = metadata[:tool_name] || "unknown_tool"
            [build_ref(name: tool_name, action: :failed, outcome: :error, turn_index: index)]
          end

          def extract_mcp_uris(content, index)
            content.scan(MCP_REF_PATTERN).flatten.uniq.map do |name|
              build_ref(name: name, action: :mentioned, turn_index: index)
            end
          end

          def extract_tool_use_blocks(content, index)
            content.scan(TOOL_USE_PATTERN).flatten.uniq.map do |name|
              build_ref(name: name, action: :called, turn_index: index)
            end
          end

          def extract_tool_results(content, index)
            content.scan(TOOL_RESULT_PATTERN).flatten.uniq.map do |name|
              build_ref(name: name, action: :called, outcome: :success, turn_index: index)
            end
          end

          def extract_cant_find_references(content, index)
            return [] unless content.match?(CANT_FIND_TOOL_PATTERN)

            [build_ref(name: "unknown_tool", action: :not_found, outcome: :not_available, turn_index: index)]
          end

          def extract_explicit_calls(content, index)
            content.scan(EXPLICIT_TOOL_CALL_PATTERN).flatten.uniq.map do |name|
              build_ref(name: name, action: :called, turn_index: index)
            end
          end

          def build_ref(name:, action:, turn_index:, outcome: nil)
            Models::ToolReference.new(
              name: name,
              action: action,
              outcome: outcome,
              turn_index: turn_index
            )
          end
        end
      end
    end
  end
end
