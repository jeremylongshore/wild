# frozen_string_literal: true

require "securerandom"
require "json"

module Wild
  module Introspection
    module Audit
      class AuditRecord
        FIELDS = %i[
          id timestamp caller_id caller_type tool_name model_name parameters
          guard_result outcome duration_ms rows_returned truncated
          error_message read_replica_used server_version
        ].freeze

        attr_reader(*FIELDS)

        def initialize(**attrs)
          assign_identity_fields(attrs)
          assign_invocation_fields(attrs)
          assign_result_fields(attrs)
          freeze
        end

        private

        def assign_identity_fields(attrs)
          @id = attrs.fetch(:id) { SecureRandom.uuid }
          @timestamp = attrs.fetch(:timestamp) { Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%3NZ") }
          @caller_id = attrs.fetch(:caller_id, "anonymous")
          @caller_type = attrs.fetch(:caller_type, "unknown")
          @server_version = attrs.fetch(:server_version, Wild::VERSION)
        end

        def assign_invocation_fields(attrs)
          @tool_name = attrs.fetch(:tool_name)
          @model_name = attrs.fetch(:model_name, nil)
          @parameters = attrs.fetch(:parameters, {})
        end

        def assign_result_fields(attrs)
          @guard_result = attrs.fetch(:guard_result)
          @outcome = attrs.fetch(:outcome)
          @duration_ms = attrs.fetch(:duration_ms)
          @rows_returned = attrs.fetch(:rows_returned, 0)
          @truncated = attrs.fetch(:truncated, false)
          @error_message = attrs.fetch(:error_message, nil)
          @read_replica_used = attrs.fetch(:read_replica_used, false)
        end

        public

        def to_h
          FIELDS.index_with { |field| public_send(field) }
        end
      end
    end
  end
end
