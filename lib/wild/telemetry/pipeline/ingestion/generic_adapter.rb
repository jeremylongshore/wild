# frozen_string_literal: true

require "json"

module Wild
  module Telemetry
    module Pipeline
      module Ingestion
        class GenericAdapter < BaseAdapter
          ROLE_MAP = {
            "user" => :user,
            "human" => :user,
            "assistant" => :assistant,
            "ai" => :assistant,
            "bot" => :assistant,
            "system" => :system,
            "tool" => :tool,
            "function" => :tool
          }.freeze

          def parse(input, source_id: nil)
            require_non_empty!(input)

            data = parse_json(input)
            sid = coerce_source_id(source_id)
            raw_turns = extract_turns(data)
            turns = build_turns(raw_turns)

            [Models::Transcript.new(
              source_type: :generic,
              source_id: sid,
              turns: turns,
              metadata: { adapter: "GenericAdapter" }
            )]
          end

          private

          def parse_json(input)
            JSON.parse(input.to_s.strip)
          rescue JSON::ParserError => e
            raise IngestionError, "Failed to parse generic conversation JSON: #{e.message}"
          end

          def extract_turns(data)
            if data.is_a?(Hash) && data["turns"].is_a?(Array)
              data["turns"]
            elsif data.is_a?(Hash) && data["messages"].is_a?(Array)
              data["messages"]
            elsif data.is_a?(Array)
              data
            else
              raise IngestionError, 'Generic JSON must contain a "turns", "messages" array, or be an array itself'
            end
          end

          def build_turns(raw_turns)
            raw_turns.filter_map { |entry| build_turn_from_entry(entry) }
          end

          def build_turn_from_entry(entry)
            return nil unless entry.is_a?(Hash)

            role_str = entry["role"].to_s.downcase
            role = ROLE_MAP[role_str]
            return nil if role.nil?

            content = entry["content"].to_s
            timestamp = parse_timestamp(entry["timestamp"])
            metadata = entry.except("role", "content", "timestamp")

            build_turn(role: role, content: content, timestamp: timestamp, metadata: metadata)
          end
        end
      end
    end
  end
end
