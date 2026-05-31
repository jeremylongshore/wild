# frozen_string_literal: true

require "json"

module Wild
  module Telemetry
    module Pipeline
      module Ingestion
        class McpLogAdapter < BaseAdapter
          def parse(input, source_id: nil)
            require_non_empty!(input)

            parsed = parse_json_array(input)
            sid = coerce_source_id(source_id)
            turns = build_turns_from_pairs(parsed)

            [Models::Transcript.new(
              source_type: :mcp_log,
              source_id: sid,
              turns: turns,
              metadata: { adapter: "McpLogAdapter", message_count: parsed.size }
            )]
          end

          private

          def parse_json_array(input)
            data = JSON.parse(input.to_s.strip)
            raise IngestionError, "MCP log must be a JSON array, got: #{data.class}" unless data.is_a?(Array)

            data
          rescue JSON::ParserError => e
            raise IngestionError, "Failed to parse MCP log JSON: #{e.message}"
          end

          def build_turns_from_pairs(messages)
            requests = {}
            turns = []

            messages.each do |msg|
              next unless msg.is_a?(Hash)

              if request?(msg)
                requests[msg["id"]] = msg
                turns << build_request_turn(msg)
              elsif response?(msg)
                turns << build_response_turn(msg, requests[msg["id"]])
              end
            end

            turns.compact
          end

          def request?(msg)
            msg.key?("method") && msg.key?("id")
          end

          def response?(msg)
            (msg.key?("result") || msg.key?("error")) && msg.key?("id") && !msg.key?("method")
          end

          def build_request_turn(msg)
            method = msg["method"] || "unknown"
            params = msg["params"] || {}
            tool_name = params["name"] || method
            content = build_request_content(method, params)

            build_turn(
              role: :user,
              content: content,
              metadata: { mcp_id: msg["id"], method: method, tool_name: tool_name }
            )
          end

          def build_request_content(method, params)
            if method == "tools/call"
              name = params["name"] || "unknown"
              args = params["arguments"] || {}
              "[mcp:request] tools/call #{name}(#{JSON.generate(args)})"
            else
              "[mcp:request] #{method} #{JSON.generate(params)}"
            end
          end

          def build_response_turn(msg, _request)
            if msg.key?("error")
              build_turn(
                role: :tool,
                content: "[mcp:error] #{JSON.generate(msg["error"])}",
                metadata: { mcp_id: msg["id"], mcp_error: true }
              )
            else
              content = extract_result_content(msg["result"])
              build_turn(
                role: :tool,
                content: "[mcp:result] #{content}",
                metadata: { mcp_id: msg["id"] }
              )
            end
          end

          def extract_result_content(result)
            return "" if result.nil?

            if result.is_a?(Hash) && result["content"].is_a?(Array)
              result["content"].filter_map { |c| c["text"] if c.is_a?(Hash) }.join(" ")
            else
              JSON.generate(result)
            end
          end
        end
      end
    end
  end
end
