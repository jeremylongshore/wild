# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/MethodLength, Metrics/ParameterLists

require "json"
require "time"

module Wild
  module Telemetry
    module Pipeline
      module TestSupport
        module TranscriptFixtures
          BASE_TIMESTAMP = Time.utc(2026, 3, 19, 14, 0, 0)

          module_function

          # ---- Claude Code JSONL ----

          def claude_code_jsonl(entries: nil)
            entries ||= default_claude_code_entries
            entries.map { |e| JSON.generate(e) }.join("\n")
          end

          def default_claude_code_entries
            [
              {
                "type" => "human",
                "message" => "Can you check the database connection pool?",
                "timestamp" => BASE_TIMESTAMP.iso8601
              },
              {
                "type" => "assistant",
                "message" => "I'll look into that. Let me use the inspect_connection tool...",
                "timestamp" => (BASE_TIMESTAMP + 5).iso8601
              },
              {
                "type" => "tool_use",
                "name" => "inspect_connection",
                "input" => {},
                "timestamp" => (BASE_TIMESTAMP + 6).iso8601
              },
              {
                "type" => "tool_result",
                "name" => "inspect_connection",
                "output" => "Pool size: 5, active: 3",
                "timestamp" => (BASE_TIMESTAMP + 7).iso8601
              }
            ]
          end

          # ---- MCP log JSON ----

          def mcp_log_json(messages: nil)
            messages ||= default_mcp_messages
            JSON.generate(messages)
          end

          def default_mcp_messages
            [
              {
                "jsonrpc" => "2.0",
                "method" => "tools/call",
                "params" => { "name" => "inspect_routes", "arguments" => {} },
                "id" => 1
              },
              {
                "jsonrpc" => "2.0",
                "result" => { "content" => [{ "type" => "text", "text" => "Found 42 routes" }] },
                "id" => 1
              }
            ]
          end

          # ---- Generic JSON ----

          def generic_json(turns: nil)
            turns ||= default_generic_turns
            JSON.generate({ "turns" => turns })
          end

          def default_generic_turns
            [
              { "role" => "user", "content" => "Show me the routes" },
              { "role" => "assistant", "content" => "Let me check..." }
            ]
          end

          # ---- Model builders ----

          def make_turn(role: :user, content: "Hello", timestamp: nil, metadata: {})
            Wild::Telemetry::Pipeline::Models::Turn.new(
              role: role,
              content: content,
              timestamp: timestamp || BASE_TIMESTAMP,
              metadata: metadata
            )
          end

          def make_intent(description: "Testing intent", confidence: 0.75, source_turn_index: 0)
            Wild::Telemetry::Pipeline::Models::Intent.new(
              description: description,
              confidence: confidence,
              source_turn_index: source_turn_index
            )
          end

          def make_tool_reference(name: "inspect_connection", action: :called, outcome: :success, turn_index: 1)
            Wild::Telemetry::Pipeline::Models::ToolReference.new(
              name: name,
              action: action,
              outcome: outcome,
              turn_index: turn_index
            )
          end

          def make_transcript(source_type: :generic, source_id: "test-001", turns: nil,
                              intents: [], tool_references: [], metadata: {})
            turns ||= [
              make_turn(role: :user, content: "Hello"),
              make_turn(role: :assistant, content: "Hi there!")
            ]
            Wild::Telemetry::Pipeline::Models::Transcript.new(
              source_type: source_type,
              source_id: source_id,
              turns: turns,
              intents: intents,
              tool_references: tool_references,
              metadata: metadata,
              created_at: BASE_TIMESTAMP
            )
          end

          def make_transcript_batch(count: 2)
            transcripts = count.times.map do |i|
              make_transcript(source_id: "batch-#{i + 1}")
            end
            Wild::Telemetry::Pipeline::Models::TranscriptBatch.new(
              transcripts: transcripts,
              metadata: { batch_id: "test-batch" },
              created_at: BASE_TIMESTAMP
            )
          end

          def turns_with_sensitive_content
            [
              make_turn(role: :user, content: "My email is user@example.com"),
              make_turn(role: :assistant, content: "API key: api_key=sk-abc123def456ghi789jkl"),
              make_turn(role: :user, content: "The path is /home/user/secrets/config.yml"),
              make_turn(role: :assistant, content: "AWS key: AKIAIOSFODNN7EXAMPLE")
            ]
          end

          def turns_with_intents
            [
              make_turn(role: :user, content: "I need to find all failing tests"),
              make_turn(role: :assistant, content: "Let me check the test results for you"),
              make_turn(role: :assistant, content: "I can't find a tool for running tests directly"),
              make_turn(role: :user, content: "There must be a way to do this")
            ]
          end

          def turns_with_tool_calls
            [
              make_turn(role: :user, content: "Check the routes"),
              make_turn(role: :assistant, content: "[tool_use] inspect_routes({})"),
              make_turn(role: :tool, content: "[tool_result:inspect_routes] Found 42 routes"),
              make_turn(role: :assistant, content: "The app has 42 routes. Also mcp://list_resources is available.")
            ]
          end
        end
      end
    end
  end
end

# rubocop:enable Metrics/ModuleLength, Metrics/MethodLength, Metrics/ParameterLists
