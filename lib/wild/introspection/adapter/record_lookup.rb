# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module RecordLookup
        DENIAL_RESPONSE = {
          status: :denied,
          reason: :model_not_allowed,
          message: "The requested model is not on the access allowlist."
        }.freeze

        NOT_FOUND_RESPONSE = {
          status: :not_found,
          message: "No record found."
        }.freeze

        def self.find_by_id(model_name, id)
          config = Wild::Introspection.configuration.model_config(model_name)
          return DENIAL_RESPONSE unless config

          execute_find(config, id)
        rescue Wild::Introspection::QueryTimeoutError
          { status: :error, reason: :query_timeout, message: "Query exceeded the configured timeout." }
        end

        def self.execute_find(config, id)
          klass = config[:klass]
          timeout_s = config[:query_timeout_ms] / 1000.0

          record = Timeout.timeout(timeout_s, Wild::Introspection::QueryTimeoutError) do
            klass.where(klass.primary_key => id).limit(1).first
          end

          record ? { status: :ok, record: record.attributes } : NOT_FOUND_RESPONSE
        end
        private_class_method :execute_find
      end
    end
  end
end
