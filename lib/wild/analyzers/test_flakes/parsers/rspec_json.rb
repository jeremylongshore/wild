# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Analyzers
    module TestFlakes
      module Parsers
        class RspecJson < Base
          def parse(input, run_id: nil, timestamp: nil)
            require_non_empty!(input)

            data = parse_json!(input)
            validate_rspec_format!(data)

            resolved_run_id = run_id || data.dig("summary", "run_id") || coerce_run_id(nil)
            resolved_ts = timestamp || default_timestamp

            extract_examples(data, resolved_run_id, resolved_ts)
          end

          private

          def parse_json!(input)
            JSON.parse(input)
          rescue JSON::ParserError => e
            raise ParseError, "Invalid JSON: #{e.message}"
          end

          def validate_rspec_format!(data)
            raise ParseError, "RSpec JSON must be a Hash" unless data.is_a?(Hash)
            raise ParseError, 'RSpec JSON must contain an "examples" key' unless data.key?("examples")
            raise ParseError, '"examples" must be an Array' unless data["examples"].is_a?(Array)
          end

          def extract_examples(data, run_id, timestamp)
            data["examples"].filter_map do |example|
              next unless example.is_a?(Hash)

              build_result_from_example(example, run_id, timestamp)
            rescue ArgumentError
              nil
            end
          end

          def build_result_from_example(example, run_id, timestamp)
            identity = extract_example_identity(example)
            build_result(
              identity: identity,
              status: map_status(example["status"]),
              run_id: run_id,
              timestamp: timestamp,
              duration_ms: example["run_time"] ? (example["run_time"].to_f * 1000).round(3) : nil,
              error_message: extract_error_message(example),
              metadata: { seed: data_seed(example) }.compact
            )
          end

          def extract_example_identity(example)
            file_path = example["file_path"] || example["location"]&.split(":")&.first || "unknown"
            description = example["full_description"] || example["description"] || "unknown"
            build_identity(
              file_path: file_path,
              test_name: extract_test_name(description),
              context: extract_context(description)
            )
          end

          def extract_context(full_description)
            parts = full_description.split
            return "" if parts.size <= 1

            parts[0..-2].join(" ")
          end

          def extract_test_name(full_description)
            parts = full_description.split
            parts.size > 1 ? parts.last : full_description
          end

          def map_status(status)
            case status
            when "passed" then :passed
            when "failed" then :failed
            when "pending" then :pending
            else :errored
            end
          end

          def extract_error_message(example)
            exception = example["exception"]
            return nil unless exception.is_a?(Hash)

            exception["message"]
          end

          def data_seed(example)
            example["seed"]
          end
        end
      end
    end
  end
end
