# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      # Manages per-action and global rate limits using SlidingWindow instances.
      # Windows are created lazily and keyed by string. Thread-safe window creation
      # is guarded by @creation_mutex; each window uses its own internal mutex.
      class RateLimiter
        MUTATION_OPERATIONS = %w[mutate mutate_destructive].freeze
        WINDOW_UNITS = { "minute" => 60, "hour" => 3600, "day" => 86_400 }.freeze
        GLOBAL_KEY_MAP = { "all_mutations" => "global:mutations", "all_reads" => "global:reads" }.freeze

        def initialize
          @windows = {}
          @creation_mutex = Mutex.new
        end

        def check(caller_id, action_name, action_config, global_rate_limits)
          action_key = "#{caller_id}:#{action_name}"

          action_result = check_window(action_key, action_config["rate_limit"])
          return action_result unless action_result[:allowed]

          global_limit = resolve_global_limit(action_config["operation"], global_rate_limits)
          check_window(global_key_for(action_config["operation"]), global_limit)
        end

        def reset!
          @creation_mutex.synchronize { @windows.clear }
        end

        def parse_rate_limit(str)
          count, unit = str.split("/")
          window = WINDOW_UNITS.fetch(unit, 60)
          { count: count.to_i, window: window }
        end

        private

        def global_key_for(operation)
          MUTATION_OPERATIONS.include?(operation) ? "global:mutations" : "global:reads"
        end

        def resolve_global_limit(operation, global_rate_limits)
          policy_key = MUTATION_OPERATIONS.include?(operation) ? "all_mutations" : "all_reads"
          global_rate_limits[policy_key] || global_rate_limits[global_key_for(operation)]
        end

        def check_window(key, rate_limit_str)
          window = window_for(key, rate_limit_str)
          return { allowed: true } if window.allow?

          { allowed: false, reason: "rate_limited", retry_after_seconds: window.retry_after_seconds }
        end

        def window_for(key, rate_limit_str)
          @windows[key] || @creation_mutex.synchronize do
            @windows[key] ||= build_window(rate_limit_str)
          end
        end

        def build_window(rate_limit_str)
          parsed = parse_rate_limit(rate_limit_str)
          SlidingWindow.new(parsed[:count], parsed[:window])
        end
      end
    end
  end
end
