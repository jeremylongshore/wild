# frozen_string_literal: true

require "json"
require "fileutils"
require "active_support/core_ext/file/atomic"

module Wild
  module Telemetry
    module Collector
      module Store
        # rubocop:disable Metrics/ClassLength -- grew past the default budget adding StorageError
        # wrapping (f-l02-6) and File.atomic_write's crash-safety/permission-preservation and
        # cross-process-locking documentation (f-l02-1, f-l02-2) on top of the existing store API;
        # no single method here is complex.
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
          rescue SystemCallError, IOError => e
            raise StorageError, "append failed: #{e.class}: #{e.message}"
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
              atomic_replace("") if File.exist?(@path)
            end
          rescue SystemCallError, IOError => e
            raise StorageError, "clear failed: #{e.class}: #{e.message}"
          end

          def size_bytes
            @mutex.synchronize do
              return 0 unless File.exist?(@path)

              File.size(@path)
            end
          end

          # Rewrites the store's file under the same @mutex #append uses, so
          # a rewrite (retention purge, size trim) can never race a
          # concurrent #append and lose it (finding f-l02-1). Yields the
          # current lines (raw strings, newline included) and expects the
          # array to keep back; returns the count of lines removed, or 0 if
          # the file does not exist or nothing was removed.
          #
          # The rewrite goes through ActiveSupport's File.atomic_write
          # (finding f-l02-2): a same-directory Tempfile, fsync'd before an
          # atomic File.rename over @path, so a crash between the write and
          # the rename leaves the original file untouched. atomic_write also
          # chown/chmods the replacement to match @path's original
          # uid/gid/mode, so a 0600 file stays 0600 (hand-rolling
          # `File.open(tmp, "wb")` picks up umask-default permissions and the
          # calling uid instead).
          #
          # The lock this rewrite runs under (@mutex, shared with #append) is
          # process-local: it does nothing for two separate processes (or
          # two separate JsonLinesStore instances) writing the same file
          # concurrently, there is no flock, and none is added here.
          # Cross-process purge/append safety on a shared file is a
          # follow-up (bead: "Add cross-process file locking to
          # JsonLinesStore for multi-process purge/append safety").
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
          rescue SystemCallError, IOError => e
            raise StorageError, "compact failed: #{e.class}: #{e.message}"
          end

          private

          def ensure_directory!
            FileUtils.mkdir_p(File.dirname(@path))
          end

          def atomic_replace(content)
            File.atomic_write(@path) do |f|
              f.write(content)
              f.flush
              f.fsync
            end
            fsync_containing_directory
          rescue StandardError
            cleanup_leftover_atomic_write_tempfiles
            raise
          end

          # Best-effort durability: the file itself is already fsync'd and
          # atomically renamed into place by File.atomic_write above, so a
          # directory entry that never made it to disk (some overlay
          # filesystems, or a platform that refuses to open/fsync a
          # directory at all) is not correctness-critical, just a smaller
          # durability guarantee than the common case gets.
          def fsync_containing_directory
            File.open(File.dirname(@path), &:fsync)
          rescue SystemCallError, NotImplementedError
            nil
          end

          # File.atomic_write's Tempfile is not unlinked when the block
          # raises (only Ruby's Tempfile finalizer will eventually clean it
          # up, at GC or process exit) so a rename failure would otherwise
          # leak a stray `.<basename><random>` file in @path's directory on
          # every failed compact/clear!. Best-effort: if the leftover is
          # already gone (a concurrent cleanup, or it never got created),
          # there is nothing left to do.
          def cleanup_leftover_atomic_write_tempfiles
            Dir.glob(File.join(File.dirname(@path), ".#{File.basename(@path)}*")).each do |leftover|
              File.delete(leftover)
            end
          rescue Errno::ENOENT
            nil
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
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
