# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module SchemaInspector
        DENIAL_RESPONSE = {
          status: :denied,
          reason: :model_not_allowed,
          message: "The requested model is not on the access allowlist."
        }.freeze

        def self.inspect_schema(model_name)
          config = Wild::Introspection.configuration.model_config(model_name)
          return DENIAL_RESPONSE unless config

          klass = config[:klass]
          {
            status: :ok,
            model: model_name,
            table_name: klass.table_name,
            columns: extract_columns(klass),
            associations: extract_associations(klass)
          }
        end

        def self.extract_columns(klass)
          klass.columns.map do |col|
            {
              name: col.name,
              type: col.type,
              sql_type: col.sql_type,
              nullable: col.null,
              default: col.default
            }
          end
        end

        def self.extract_associations(klass)
          klass.reflect_on_all_associations.map do |assoc|
            {
              name: assoc.name.to_s,
              type: assoc.macro,
              target_model: assoc.class_name,
              foreign_key: assoc.foreign_key
            }
          end
        end

        private_class_method :extract_columns, :extract_associations
      end
    end
  end
end
