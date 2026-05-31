# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module FilteredLookup
        HARD_ROW_CEILING = 1000

        DENIAL_RESPONSE = {
          status: :denied,
          reason: :model_not_allowed,
          message: "The requested model is not on the access allowlist."
        }.freeze

        def self.find_by_filter(model_name, field:, value:)
          config = Wild::Introspection.configuration.model_config(model_name)
          return DENIAL_RESPONSE unless config

          klass = config[:klass]
          field_str = field.to_s

          return DENIAL_RESPONSE unless valid_field?(klass, field_str)

          max_rows = [config[:max_rows], HARD_ROW_CEILING].min
          timeout_s = config[:query_timeout_ms] / 1000.0

          execute_query(klass, field_str, value, max_rows, timeout_s)
        rescue Wild::Introspection::QueryTimeoutError
          { status: :error, reason: :query_timeout, message: "Query exceeded the configured timeout." }
        end

        def self.valid_field?(klass, field)
          klass.column_names.include?(field)
        end
        private_class_method :valid_field?

        def self.execute_query(klass, field, value, max_rows, timeout_s)
          results = Timeout.timeout(timeout_s, Wild::Introspection::QueryTimeoutError) do
            klass.where(field => value).limit(max_rows + 1).to_a
          end

          build_result(results, max_rows)
        end
        private_class_method :execute_query

        def self.build_result(results, max_rows)
          truncated = results.size > max_rows
          results = results.first(max_rows) if truncated

          { status: :ok, records: results.map(&:attributes), truncated: truncated, count: results.size }
        end
        private_class_method :build_result
      end
    end
  end
end
