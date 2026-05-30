# frozen_string_literal: true

require "json"

module Wild
  module CapabilityGate
    module Audit
      # Append-only JSON Lines writer for audit events.
      #
      # Each audit event is serialized as a single JSON object on one line,
      # appended to the configured file path. This format is machine-parseable,
      # grep-friendly, and supports concurrent append from multiple processes.
      #
      # The writer only appends — it never reads, truncates, or modifies
      # existing log content.
      class JsonLinesWriter
        attr_reader :path

        def initialize(path:)
          @path = String(path)
          freeze
        end

        # Write an audit event to the log file.
        # Accepts an Audit::Event or any object responding to #to_h.
        def write(event)
          line = "#{JSON.generate(event.to_h)}\n"
          File.open(@path, "a") { |f| f.write(line) }
          nil
        end
      end
    end
  end
end
