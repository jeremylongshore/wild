# frozen_string_literal: true

require "json"

module Wild
  module Introspection
    module Audit
      module AuditLogger
        # rubocop:disable Naming/PredicateMethod -- logging is a command whose
        # boolean result reports whether persistence occurred.
        def self.log(audit_record)
          path = Wild::Introspection.configuration.audit_log_path
          unless path
            warn("[wild:introspection] audit record not persisted: audit_log_path is not configured")
            return false
          end

          File.open(path, "a") { |f| f.puts(JSON.generate(audit_record.to_h)) }
          true
        end
        # rubocop:enable Naming/PredicateMethod
      end
    end
  end
end
