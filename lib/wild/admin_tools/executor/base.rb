# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      class Base
        include StateCapture

        def preview(action_name, params = {})
          entry = lookup_action!(action_name)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          data = send(entry[:preview], params)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          Result.new(
            status: :preview,
            action: action_name,
            operation: entry[:operation],
            data: data,
            metadata: { duration_ms: (elapsed * 1000).round(2) }
          )
        rescue Wild::AdminTools::Error
          raise
        rescue StandardError => e
          raise AdapterError.new("#{action_name} preview failed: #{e.message}", original_error: e)
        end

        def execute(action_name, params = {})
          entry = lookup_action!(action_name)
          before, data, after, elapsed = run_with_snapshots(entry, action_name, params)

          Result.new(
            status: :success, action: action_name, operation: entry[:operation],
            data: data, before_snapshot: before, after_snapshot: after,
            metadata: { duration_ms: (elapsed * 1000).round(2) }
          )
        rescue Wild::AdminTools::Error
          raise
        rescue StandardError => e
          raise AdapterError.new("#{action_name} execution failed: #{e.message}", original_error: e)
        end

        def handles?(action_name)
          self.class::ACTION_MAP.key?(action_name)
        end

        def action_names
          self.class::ACTION_MAP.keys
        end

        private

        def run_with_snapshots(entry, action_name, params)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          mutating = entry[:operation] != "read"
          before = mutating ? capture_before_snapshot(action_name, params) : nil
          data = send(entry[:execute], params)
          after = mutating ? capture_after_snapshot(action_name, params) : nil
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          [before, data, after, elapsed]
        end

        def lookup_action!(action_name)
          self.class::ACTION_MAP.fetch(action_name) do
            raise ActionNotFoundError, action_name
          end
        end
      end
    end
  end
end
