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

          # Rewrites the store's file under the same @mutex #append uses, so
          # a rewrite (retention purge, size trim) can never race a
          # concurrent #append and lose it (finding f-l02-1: an untracked
          # 2000-append / 300-purge race dropped 425 events before this
          # existed). Yields the current lines (raw strings, newline
          # included) and expects the array to keep back; returns the count
          # of lines removed, or 0 if the file does not exist or nothing was
          # removed.
          #
          # The rewrite itself goes through a temp file in the same
          # directory, fsync'd before an atomic File.rename over @path
          # (finding f-l02-2): a crash between the write and the rename
          # leaves the original file untouched, never truncated mid-write.
          def compact
            @mutex.synchronize do
              return 0 unless File.exist?(@path)

              lines = File.readlines(@path)
              kept_lines = yield(lines)
              removed_count = lines.length - kept_lines.length
              return 0 if removed_count.zero?

              atomic_replace(kept_lines.join)
              removed_count
            end
          end

          private

          def ensure_directory!
            FileUtils.mkdir_p(File.dirname(@path))
          end

          def atomic_replace(content)
            tmp_path = "#{@path}.tmp-#{Process.pid}-#{Thread.current.object_id}"
            File.open(tmp_path, "wb") do |f|
              f.write(content)
              f.flush
              f.fsync
            end
            File.rename(tmp_path, @path)
          rescue StandardError
            File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
            raise
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
