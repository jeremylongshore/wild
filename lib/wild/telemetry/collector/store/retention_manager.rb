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

          def purge_before(cutoff)
            kept_lines = []
            removed_count = 0

            File.foreach(@store.path) do |line|
              data = safe_parse(line)
              if data && data[:received_at] && data[:received_at] < cutoff
                removed_count += 1
              else
                kept_lines << line
              end
            end

            return 0 if removed_count.zero?

            File.write(@store.path, kept_lines.join)
            removed_count
          end

          def remove_oldest_until_within_limit
            lines = File.readlines(@store.path)
            removed_count = 0

            while total_size(lines) > @max_size_bytes && !lines.empty?
              lines.shift
              removed_count += 1
            end

            return 0 if removed_count.zero?

            File.write(@store.path, lines.join)
            removed_count
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
