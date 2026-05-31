# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class RailsCacheAdapter < CacheAdapter
          def read_key(cache_key)
            require_rails_cache!
            value = Rails.cache.read(cache_key)
            return { cache_key: cache_key, exists: false, value: nil, byte_size: 0 } if value.nil?

            serialized = Marshal.dump(value)
            {
              cache_key: cache_key,
              exists: true,
              value: value,
              byte_size: serialized.bytesize
            }
          end

          def list_keys(prefix:, limit: 50)
            require_rails_cache!
            store = Rails.cache
            unless store.respond_to?(:keys)
              raise AdapterError,
                    "list_keys requires a cache store that supports key listing"
            end

            keys = store.keys.select { |k| k.start_with?(prefix) }
            keys.first(limit).map { |k| { cache_key: k } }
          end

          def cache_stats
            require_rails_cache!
            store = Rails.cache
            if store.respond_to?(:stats)
              store.stats
            else
              { store_class: store.class.name }
            end
          end

          def count_matching_keys(pattern)
            require_rails_cache!
            store = Rails.cache
            unless store.respond_to?(:keys)
              raise AdapterError,
                    "count_matching_keys requires a cache store that supports key listing"
            end

            store.keys.count { |k| k.start_with?(pattern) }
          end

          def delete_key!(cache_key)
            require_rails_cache!
            existed = Rails.cache.exist?(cache_key)
            Rails.cache.delete(cache_key)
            { cache_key: cache_key, deleted: existed }
          end

          def delete_matching!(pattern)
            require_rails_cache!
            store = Rails.cache
            unless store.respond_to?(:keys)
              raise AdapterError,
                    "delete_matching requires a cache store that supports key listing"
            end

            keys = store.keys.select { |k| k.start_with?(pattern) }
            keys.each { |k| store.delete(k) }
            { pattern: pattern, deleted_count: keys.size }
          end

          private

          def require_rails_cache!
            return if defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache

            raise AdapterError, "Rails.cache is not available. Ensure Rails is loaded and cache is configured."
          end
        end
      end
    end
  end
end
