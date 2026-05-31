# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Analyzers
    module TestFlakes
      module Parsers
        class MinitestJson < Base
          STATUS_MAP = {
            "pass" => :passed, "passed" => :passed, "ok" => :passed,
            "fail" => :failed, "failed" => :failed, "failure" => :failed,
            "error" => :errored, "errored" => :errored,
            "skip" => :skipped, "skipped" => :skipped
          }.freeze

          def parse(input, run_id: nil, timestamp: nil)
            require_non_empty!(input)

            data = parse_json!(input)
            validate_minitest_format!(data)

            extract_tests(data, coerce_run_id(run_id), timestamp || default_timestamp)
          end

          private

          def parse_json!(input)
            JSON.parse(input)
          rescue JSON::ParserError => e
            raise ParseError, "Invalid JSON: #{e.message}"
          end

          def validate_minitest_format!(data)
            raise ParseError, "Minitest JSON must be a Hash" unless data.is_a?(Hash)

            return if data.key?("tests") || data.key?("results")

            raise ParseError, 'Minitest JSON must contain "tests" or "results" key'
          end

          def extract_tests(data, run_id, timestamp)
            tests = data["tests"] || data["results"] || []
            raise ParseError, '"tests" must be an Array' unless tests.is_a?(Array)

            tests.filter_map do |test|
              next unless test.is_a?(Hash)

              build_result_from_test(test, run_id, timestamp)
            rescue ArgumentError
              nil
            end
          end

          def build_result_from_test(test, run_id, timestamp)
            identity = extract_identity(test)
            build_result(
              identity: identity,
              status: map_status(test["result"] || test["status"] || "pass"),
              run_id: run_id,
              timestamp: timestamp,
              duration_ms: test["time"] ? (test["time"].to_f * 1000).round(3) : nil,
              error_message: (test["failure"] || test["error"] || test["message"])&.to_s
            )
          end

          def extract_identity(test)
            name = test["name"] || test["test_name"] || "unknown"
            klass = test["class"] || test["suite"] || ""
            file_path = test["file"] || klass_to_file(klass)
            build_identity(
              file_path: file_path.empty? ? "unknown" : file_path,
              test_name: name,
              context: klass
            )
          end

          def map_status(raw)
            STATUS_MAP.fetch(raw.to_s.downcase, :errored)
          end

          def klass_to_file(klass)
            return "" if klass.to_s.empty?

            "#{klass.gsub("::", "/")}_test.rb"
          end
        end
      end
    end
  end
end
