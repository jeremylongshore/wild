# frozen_string_literal: true

module Wild
  module Introspection
    module Guard
      module ResultFilter
        def self.filter_record(record_hash, accessible_columns)
          record_hash.select { |key, _| accessible_columns.include?(key.to_s) }
        end

        def self.filter_records(records_array, accessible_columns)
          records_array.map { |record| filter_record(record, accessible_columns) }
        end

        def self.filter_schema_columns(columns_array, accessible_columns)
          columns_array.select { |col| accessible_columns.include?(col[:name].to_s) }
        end
      end
    end
  end
end
