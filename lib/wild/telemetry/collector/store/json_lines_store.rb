# frozen_string_literal: true

require "json"
require "fileutils"

module Wild
  module Telemetry
    module Collector
      module Store
        class JsonLinesStore < Base
          attr_reader :path

          def initialize(path:)
            super()
            @path = path
            @mutex = Mutex.new
            ensure_directory!
          end

          def append(envelope)
            line = JSON.generate(envelope.to_h)
            @mutex.synchronize do
              File.open(@path, "a") { |f| f.puts(line) }
            end
            envelope
          end

          def recent(limit: 50)
            @mutex.synchronize do
              return [] unless File.exist?(@path)

              lines = File.readlines(@path).last(limit).reverse
              lines.filter_map { |line| parse_envelope(line) }
            end
          end

          def find(timestamp:, event_type:)
            @mutex.synchronize do
              return nil unless File.exist?(@path)

              File.foreach(@path) do |line|
                envelope = parse_envelope(line)
                return envelope if envelope&.timestamp == timestamp && envelope&.event_type == event_type
              end
              nil
            end
          end

          def count
            @mutex.synchronize do
              return 0 unless File.exist?(@path)

              File.foreach(@path).count
            end
          end

          def query(event_type: nil, since: nil, before: nil)
            @mutex.synchronize do
              return [] unless File.exist?(@path)

              results = []
              File.foreach(@path) do |line|
                envelope = parse_envelope(line)
                next unless envelope
                next unless matches_query?(envelope, event_type: event_type, since: since, before: before)

                results << envelope
              end
              results
            end
          end

          def clear!
            @mutex.synchronize do
              File.write(@path, "") if File.exist?(@path)
            end
          end

          def size_bytes
            @mutex.synchronize do
              return 0 unless File.exist?(@path)

              File.size(@path)
            end
          end

          private

          def ensure_directory!
            FileUtils.mkdir_p(File.dirname(@path))
          end

          def parse_envelope(line)
            data = JSON.parse(line.strip, symbolize_names: true)
            Schema::EventEnvelope.new(**data)
          rescue JSON::ParserError, ArgumentError, TypeError
            nil
          end

          def matches_query?(envelope, event_type:, since:, before:)
            return false if event_type && envelope.event_type != event_type
            return false if since && envelope.timestamp < since
            return false if before && envelope.timestamp >= before

            true
          end
        end
      end
    end
  end
end
