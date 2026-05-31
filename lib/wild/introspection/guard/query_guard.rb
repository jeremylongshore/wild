# frozen_string_literal: true

module Wild
  module Introspection
    module Guard
      module QueryGuard
        DENIAL_RESPONSE = {
          status: :denied,
          reason: :model_not_allowed,
          message: "The requested model is not on the access allowlist."
        }.freeze

        AUTH_DENIAL = {
          status: :denied,
          reason: :auth_required,
          message: "Authentication is required."
        }.freeze

        def self.inspect_schema(model_name, request_context:)
          recorder_opts = { tool_name: "inspect_model_schema", model_name: model_name,
                            parameters: {}, request_context: request_context }
          Audit::Recorder.record(**recorder_opts) do
            next AUTH_DENIAL unless request_context.authenticated?

            accessible = ColumnResolver.accessible_columns(model_name)
            next DENIAL_RESPONSE unless accessible

            result = Adapter::SchemaInspector.inspect_schema(model_name)
            next result unless result[:status] == :ok

            result.merge(
              columns: ResultFilter.filter_schema_columns(result[:columns], accessible)
            )
          end
        end

        def self.find_by_id(model_name, id, request_context:)
          recorder_opts = { tool_name: "lookup_record_by_id", model_name: model_name,
                            parameters: { id: id }, request_context: request_context }
          Audit::Recorder.record(**recorder_opts) do
            next AUTH_DENIAL unless request_context.authenticated?

            accessible = ColumnResolver.accessible_columns(model_name)
            next DENIAL_RESPONSE unless accessible

            result = Adapter::RecordLookup.find_by_id(model_name, id)
            next result unless result[:status] == :ok

            result.merge(
              record: ResultFilter.filter_record(result[:record], accessible)
            )
          end
        end

        def self.find_by_filter(model_name, field:, value:, request_context:)
          params = { field: field, value: value }
          recorder_opts = { tool_name: "find_records_by_filter", model_name: model_name,
                            parameters: params, request_context: request_context }
          Audit::Recorder.record(**recorder_opts) do
            next AUTH_DENIAL unless request_context.authenticated?

            accessible = ColumnResolver.accessible_columns(model_name)
            next DENIAL_RESPONSE unless accessible
            next DENIAL_RESPONSE unless accessible.include?(field.to_s)

            result = Adapter::FilteredLookup.find_by_filter(model_name, field: field, value: value)
            next result unless result[:status] == :ok

            result.merge(
              records: ResultFilter.filter_records(result[:records], accessible)
            )
          end
        end
      end
    end
  end
end
