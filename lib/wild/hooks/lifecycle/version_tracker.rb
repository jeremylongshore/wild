# frozen_string_literal: true

module Wild
  module Hooks
    module Lifecycle
      # Tracks version history for hook definitions.
      class VersionTracker
        VersionEntry = Struct.new(:hook_name, :version, :changed_at)

        def initialize
          @history = Hash.new { |h, k| h[k] = [] }
          @mutex   = Mutex.new
        end

        def record(hook_name, version)
          entry = VersionEntry.new(
            hook_name: hook_name,
            version: version,
            changed_at: Time.now.utc
          )
          @mutex.synchronize { @history[hook_name] << entry }
          entry
        end

        def history_for(hook_name)
          @mutex.synchronize { @history[hook_name].dup }
        end

        def current_version(hook_name)
          @mutex.synchronize { @history[hook_name].last&.version }
        end

        def all_history
          @mutex.synchronize { @history.transform_values(&:dup) }
        end

        def clear!
          @mutex.synchronize { @history.clear }
        end
      end
    end
  end
end
