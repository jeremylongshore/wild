# frozen_string_literal: true

require "json"

module Wild
  module Telemetry
    module Pipeline
      module Ingestion
        class ClaudeCodeAdapter < BaseAdapter
          TYPE_TO_ROLE = {
            "human" => :user,
            "user" => :user,
            "assistant" => :assistant,
            "tool_use" => :tool,
            "tool_result" => :tool,
            "system" => :system
          }.freeze

          def parse(input, source_id: nil)
            require_non_empty!(input)

            lines = input.to_s.strip.split("\n").reject { |l| l.strip.empty? }
            raise IngestionError, "input contains no non-empty lines" if lines.empty?

            sid = coerce_source_id(source_id)
            turns = parse_lines(lines)

            [Models::Transcript.new(
              source_type: :claude_code,
              source_id: sid,
              turns: turns,
              metadata: { adapter: "ClaudeCodeAdapter", line_count: lines.size }
            )]
          end

          private

          def parse_lines(lines)
            lines.filter_map { |line| parse_line(line) }
          end

          def parse_line(line)
            parsed = JSON.parse(line)
            return nil unless parsed.is_a?(Hash)

            role = resolve_role(parsed)
            return nil if role.nil?

            content = extract_content(parsed)
            timestamp = parse_timestamp(parsed["timestamp"])
            metadata = extract_metadata(parsed)

            build_turn(role: role, content: content, timestamp: timestamp, metadata: metadata)
          rescue JSON::ParserError
            nil
          end

          def resolve_role(parsed)
            type = parsed["type"].to_s
            TYPE_TO_ROLE[type]
          end

          def extract_content(parsed)
            return extract_tool_use_content(parsed) if parsed["type"] == "tool_use"
            return extract_tool_result_content(parsed) if parsed["type"] == "tool_result"

            parsed["message"] || parsed["content"] || ""
          end

          def extract_tool_use_content(parsed)
            name = parsed["name"] || "unknown_tool"
            input = parsed["input"]
            input ? "#{name}(#{JSON.generate(input)})" : name
          end

          def extract_tool_result_content(parsed)
            name = parsed["name"] || "unknown_tool"
            output = parsed["output"] || parsed["content"] || ""
            "[tool_result:#{name}] #{output}"
          end

          def extract_metadata(parsed)
            meta = {}
            meta[:tool_name] = parsed["name"] if parsed["name"]
            meta[:tool_input] = parsed["input"] if parsed["input"]
            meta[:tool_output] = parsed["output"] if parsed["output"]
            meta
          end
        end
      end
    end
  end
end
