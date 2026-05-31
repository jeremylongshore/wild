# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module ModelResolver
        def self.resolve(model_name)
          config = Wild::Introspection.configuration.model_config(model_name)
          return nil unless config

          build_metadata(model_name, config)
        end

        def self.build_metadata(model_name, config)
          klass = config[:klass]
          {
            name: model_name, table_name: klass.table_name, primary_key: klass.primary_key,
            abstract: klass.abstract_class?, max_rows: config[:max_rows],
            query_timeout_ms: config[:query_timeout_ms]
          }
        end
        private_class_method :build_metadata

        def self.allowed?(model_name)
          Wild::Introspection.configuration.model_allowed?(model_name)
        end
      end
    end
  end
end
