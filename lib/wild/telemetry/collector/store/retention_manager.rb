# frozen_string_literal: true

require "json"
require "time"

module Wild
  module Telemetry
    module Collector
      module Store
        class RetentionManager
          attr_reader :retention_days, :max_size_bytes

          def initialize(store:, retention_days: 90, max_size_bytes: nil)
            @store = store
            @retention_days = retention_days
            @max_size_bytes = max_size_bytes
          end

          def purge_expired
            return 0 unless @store.is_a?(JsonLinesStore) && File.exist?(@store.path)

            cutoff = (Time.now.utc - (@retention_days * 86_400)).iso8601(3)
            purge_before(cutoff)
          end

          def purge_oversized
            return 0 unless @max_size_bytes && @store.is_a?(JsonLinesStore) && File.exist?(@store.path)
            return 0 unless @store.size_bytes > @max_size_bytes

            remove_oldest_until_within_limit
          end

          def purge_all
            expired_count = purge_expired
            oversized_count = purge_oversized
            expired_count + oversized_count
          end

          private

          # Both purge paths route through JsonLinesStore#compact so the
          # read-modify-write happens under the store's own @mutex (finding
          # f-l02-1) and the rewrite is an atomic, fsync'd rename rather
          # than an in-place truncate (finding f-l02-2). A failure here
          # (disk full mid-rewrite, a rename that cannot land) is not
          # swallowed: #compact re-raises, and it propagates out of
          # purge_before/remove_oldest_until_within_limit/purge_expired/
          # purge_oversized/purge_all so a caller (a scheduler, a rake task)
          # sees a real exception instead of a purge that silently returned
          # 0 while having actually failed.
          def purge_before(cutoff)
            @store.compact do |lines|
              lines.reject do |line|
                data = safe_parse(line)
                data && data[:received_at] && data[:received_at] < cutoff
              end
            end
          end

          def remove_oldest_until_within_limit
            @store.compact do |lines|
              kept = lines.dup
              kept.shift while total_size(kept) > @max_size_bytes && !kept.empty?
              kept
            end
          end

          def total_size(lines)
            lines.sum(&:bytesize)
          end

          def safe_parse(line)
            JSON.parse(line.strip, symbolize_names: true)
          rescue JSON::ParserError
            nil
          end
        end
      end
    end
  end
end
