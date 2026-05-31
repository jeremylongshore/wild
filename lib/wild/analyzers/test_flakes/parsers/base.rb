# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Parsers
        class Base
          def self.parse(input, run_id: nil, timestamp: nil)
            new.parse(input, run_id: run_id, timestamp: timestamp)
          end

          def parse(input, run_id: nil, timestamp: nil)
            raise NotImplementedError, "#{self.class}#parse is not implemented"
          end

          private

          def require_non_empty!(input)
            raise ParseError, "input cannot be nil or empty" if input.to_s.strip.empty?
          end

          def default_timestamp
            require "time"
            Time.now.utc
          end

          def coerce_run_id(run_id)
            run_id || "run-#{Time.now.utc.to_i}"
          end

          def build_identity(file_path:, test_name:, context: nil)
            Models::TestIdentity.new(
              file_path: file_path.to_s.empty? ? "unknown" : file_path,
              test_name: test_name,
              context: context
            )
          end

          # rubocop:disable Metrics/ParameterLists
          def build_result(identity:, status:, run_id:, timestamp:, duration_ms: nil,
                           error_message: nil, metadata: {})
            Models::TestResult.new(
              test_identity: identity,
              status: status,
              run_id: run_id,
              timestamp: timestamp,
              duration_ms: duration_ms,
              error_message: error_message,
              metadata: metadata
            )
          end
          # rubocop:enable Metrics/ParameterLists
        end
      end
    end
  end
end
