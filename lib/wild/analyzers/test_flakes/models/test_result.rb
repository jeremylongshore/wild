# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Models
        class TestResult
          VALID_STATUSES = %i[passed failed errored skipped pending].freeze

          attr_reader :test_identity, :status, :duration_ms, :run_id, :timestamp,
                      :error_message, :metadata

          # rubocop:disable Metrics/ParameterLists
          def initialize(test_identity:, status:, run_id:, timestamp:,
                         duration_ms: nil, error_message: nil, metadata: {})
            validate_identity!(test_identity)
            validate_status!(status)
            validate_run_id!(run_id)
            validate_timestamp!(timestamp)

            @test_identity = test_identity
            @status = status.to_sym
            @run_id = run_id.to_s.freeze
            @timestamp = timestamp
            @duration_ms = duration_ms&.to_f
            @error_message = error_message&.to_s&.freeze
            @metadata = (metadata || {}).freeze
          end
          # rubocop:enable Metrics/ParameterLists

          def passed?
            status == :passed
          end

          def failed?
            %i[failed errored].include?(status)
          end

          def skipped?
            %i[skipped pending].include?(status)
          end

          def to_h
            {
              test_identity: test_identity.to_h,
              status: status,
              run_id: run_id,
              timestamp: timestamp.iso8601,
              duration_ms: duration_ms,
              error_message: error_message,
              metadata: metadata
            }
          end

          private

          def validate_identity!(identity)
            return if identity.is_a?(TestIdentity)

            raise ArgumentError, "test_identity must be a TestIdentity, got: #{identity.class}"
          end

          def validate_status!(status)
            sym = status.to_sym
            return if VALID_STATUSES.include?(sym)

            raise ArgumentError, "status must be one of #{VALID_STATUSES.inspect}, got: #{status.inspect}"
          end

          def validate_run_id!(run_id)
            raise ArgumentError, "run_id cannot be nil or empty" if run_id.to_s.strip.empty?
          end

          def validate_timestamp!(timestamp)
            raise ArgumentError, "timestamp cannot be nil" if timestamp.nil?
            raise ArgumentError, "timestamp must respond to iso8601" unless timestamp.respond_to?(:iso8601)
          end
        end
      end
    end
  end
end
