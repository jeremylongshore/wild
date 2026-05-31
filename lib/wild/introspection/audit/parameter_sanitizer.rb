# frozen_string_literal: true

module Wild
  module Introspection
    module Audit
      module ParameterSanitizer
        REDACTED = "[REDACTED]"

        def self.sanitize(tool_name, model_name, raw_params)
          case tool_name
          when "inspect_model_schema"
            { sanitized: true, fields: {} }
          when "lookup_record_by_id"
            { sanitized: true, fields: { id: raw_params[:id] } }
          when "find_records_by_filter"
            sanitize_filter_params(model_name, raw_params)
          end
        end

        def self.sanitize_filter_params(model_name, raw_params)
          field = raw_params[:field].to_s
          blocked = Wild::Introspection.configuration.blocked_columns_for(model_name)
          value = blocked.include?(field) ? REDACTED : raw_params[:value]

          { sanitized: true, fields: { field: field, value: value } }
        end
        private_class_method :sanitize_filter_params
      end
    end
  end
end
