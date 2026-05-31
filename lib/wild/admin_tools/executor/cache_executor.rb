# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      class CacheExecutor < Base
        ACTION_MAP = {
          "inspect_cache_key" => { preview: :preview_inspect_cache_key, execute: :execute_inspect_cache_key,
                                   operation: "read" },
          "inspect_cache_stats" => { preview: :preview_inspect_cache_stats, execute: :execute_inspect_cache_stats,
                                     operation: "read" },
          "list_cache_keys" => { preview: :preview_list_cache_keys, execute: :execute_list_cache_keys,
                                 operation: "read" },
          "invalidate_cache_key" => { preview: :preview_invalidate_cache_key,
                                      execute: :execute_invalidate_cache_key, operation: "mutate" },
          "invalidate_cache_pattern" => { preview: :preview_invalidate_cache_pattern,
                                          execute: :execute_invalidate_cache_pattern,
                                          operation: "mutate_destructive" }
        }.freeze

        private

        def adapter
          Wild::AdminTools.configuration.cache_adapter
        end

        # --- inspect_cache_key ---

        def preview_inspect_cache_key(params)
          entry = adapter.read_key(params[:cache_key])
          { entry: entry }
        end

        def execute_inspect_cache_key(params)
          adapter.read_key(params[:cache_key])
        end

        # --- inspect_cache_stats ---

        def preview_inspect_cache_stats(_params)
          stats = adapter.cache_stats
          { stats: stats }
        end

        def execute_inspect_cache_stats(_params)
          { stats: adapter.cache_stats }
        end

        # --- list_cache_keys ---

        def preview_list_cache_keys(params)
          keys = adapter.list_keys(**params.slice(:prefix, :limit))
          { keys: keys, count: keys.size }
        end

        def execute_list_cache_keys(params)
          keys = adapter.list_keys(**params.slice(:prefix, :limit))
          { keys: keys, count: keys.size }
        end

        # --- invalidate_cache_key ---

        def preview_invalidate_cache_key(params)
          entry = adapter.read_key(params[:cache_key])
          { cache_key: params[:cache_key], exists: entry && entry[:exists], will_invalidate: true }
        end

        def execute_invalidate_cache_key(params)
          adapter.delete_key!(params[:cache_key])
        end

        # --- invalidate_cache_pattern ---

        def preview_invalidate_cache_pattern(params)
          count = adapter.count_matching_keys(params[:pattern])
          { pattern: params[:pattern], estimated_affected: count }
        end

        def execute_invalidate_cache_pattern(params)
          adapter.delete_matching!(params[:pattern])
        end
      end
    end
  end
end
