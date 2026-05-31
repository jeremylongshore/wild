# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class CacheAdapter
          # Read methods (no side effects)
          def read_key(_cache_key)
            raise NotImplementedError, "#{self.class}#read_key"
          end

          def list_keys(**_options)
            raise NotImplementedError, "#{self.class}#list_keys"
          end

          def cache_stats
            raise NotImplementedError, "#{self.class}#cache_stats"
          end

          def count_matching_keys(_pattern)
            raise NotImplementedError, "#{self.class}#count_matching_keys"
          end

          # Write methods (mutating — suffixed with !)
          def delete_key!(_cache_key)
            raise NotImplementedError, "#{self.class}#delete_key!"
          end

          def delete_matching!(_pattern)
            raise NotImplementedError, "#{self.class}#delete_matching!"
          end
        end
      end
    end
  end
end
