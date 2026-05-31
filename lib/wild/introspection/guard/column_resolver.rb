# frozen_string_literal: true

module Wild
  module Introspection
    module Guard
      module ColumnResolver
        def self.accessible_columns(model_name)
          config = Wild::Introspection.configuration
          model_cfg = config.model_config(model_name)
          return nil unless model_cfg

          base = base_columns(model_cfg)
          (base - config.blocked_columns_for(model_name)).freeze
        end

        def self.base_columns(model_cfg)
          all_columns = model_cfg[:klass].column_names

          case model_cfg[:columns_mode]
          when :explicit then model_cfg[:explicit_columns] & all_columns
          else all_columns.dup
          end
        end
        private_class_method :base_columns
      end
    end
  end
end
