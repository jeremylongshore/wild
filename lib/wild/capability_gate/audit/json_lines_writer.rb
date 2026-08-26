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
        # Accepts an Audit::Event, a Hash already built by Audit::Event#to_h
        # (evaluator.rb passes the hash it already built once — item 13 of the
        # f-l08 addendum), or any other object responding to #to_h.
        #
        # f-l08 addendum item 5: Audit::Event.coerce_context already bounds
        # `context` at construction time (rejects NaN/Infinity, invalid
        # encodings, and oversized payloads before the event exists), so this
        # should never see unserializable data through the normal Gate flow.
        # It is defense-in-depth for the ONE thing that coercion cannot see:
        # every other event field. A genuinely unserializable line must not
        # drop the whole audit record — write a bounded stand-in instead so the
        # decision is still on record, with a note that the context was
        # dropped for being unserializable.
        def write(event)
          hash = event.to_h
          line = serialize(hash)
          File.open(@path, "a") { |f| f.write(line) }
          nil
        end

        private

        def serialize(hash)
          "#{JSON.generate(hash)}\n"
        rescue JSON::GeneratorError, JSON::NestingError, Encoding::UndefinedConversionError
          "#{JSON.generate(unserializable_fallback(hash))}\n"
        end

        def unserializable_fallback(hash)
          extra = hash["extra"].is_a?(Hash) ? hash["extra"] : {}
          hash.merge(
            "extra" => extra.merge("context" => { "dropped" => true, "reason" => "context not JSON-serializable" })
          )
        end
      end
    end
  end
end
