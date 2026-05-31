# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module WritePrevention
        FORBIDDEN_METHODS = %i[
          save save!
          create create!
          update update!
          update_all
          destroy destroy!
          destroy_all
          delete delete_all
          insert insert_all
          upsert upsert_all
          touch
          increment! decrement!
          toggle!
        ].freeze

        WRITE_SQL_PATTERN = /\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE|GRANT|REVOKE)\b/i

        def self.write_method?(name)
          FORBIDDEN_METHODS.include?(name.to_sym)
        end

        def self.assert_not_write_method!(name)
          return unless write_method?(name)

          raise WriteAttemptError, "Write method '#{name}' is forbidden. This system is read-only."
        end

        def self.assert_sql_read_only!(sql)
          return unless sql.is_a?(String)

          # Strip quoted strings to avoid false positives on values like 'Grant' or '%update%'.
          # Defense-in-depth: the system uses parameterized queries, so values should never
          # appear in the SQL string, but this handles edge cases safely.
          stripped = sql.gsub(/'[^']*'/, "''").gsub(/"[^"]*"/, '""')
          return unless stripped.match?(WRITE_SQL_PATTERN)

          raise WriteAttemptError, "Write SQL detected. This system is read-only."
        end
      end
    end
  end
end
