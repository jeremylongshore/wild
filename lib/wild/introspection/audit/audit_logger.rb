# frozen_string_literal: true

require "json"

module Wild
  module Introspection
    module Audit
      module AuditLogger
        def self.log(audit_record)
          path = Wild::Introspection.configuration.audit_log_path
          return unless path

          File.open(path, "a") { |f| f.puts(JSON.generate(audit_record.to_h)) }
        end
      end
    end
  end
end
