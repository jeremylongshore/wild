# frozen_string_literal: true

require "digest"
require "time"

module Wild
  module AdminTools
    module Executor
      module StateCapture
        private

        def capture_before_snapshot(action_name, params)
          capture_snapshot(:before, action_name, params)
        end

        def capture_after_snapshot(action_name, params)
          capture_snapshot(:after, action_name, params)
        end

        def capture_snapshot(phase, action_name, params)
          case snapshot_category(action_name)
          when :job   then capture_job_snapshot(phase, params)
          when :cache then capture_cache_snapshot(phase, params)
          when :flag  then capture_flag_snapshot(phase, params)
          end
        end

        def snapshot_category(action_name)
          return :job if action_name.match?(/job|queue/)
          return :cache if action_name.match?(/cache/)

          :flag if action_name.match?(/flag/)
        end

        def capture_job_snapshot(phase, params)
          job_id = params[:job_id]
          return nil unless job_id

          job = Wild::AdminTools.configuration.job_adapter.find_job(job_id)
          return nil unless job

          phase == :before ? job_before_snapshot(job) : job_after_snapshot(job)
        end

        def job_before_snapshot(job)
          job.slice(:job_id, :status, :queue, :error_class, :failed_at, :retry_count)
        end

        def job_after_snapshot(job)
          job.slice(:job_id, :status, :enqueued_at, :discarded_at)
        end

        def capture_cache_snapshot(phase, params)
          cache_key = params[:cache_key] || params[:pattern]
          return nil unless cache_key

          entry = Wild::AdminTools.configuration.cache_adapter.read_key(cache_key)
          phase == :before ? cache_before_snapshot(cache_key, entry) : cache_after_snapshot(cache_key, entry)
        end

        def cache_before_snapshot(cache_key, entry)
          return nil unless entry

          {
            cache_key: cache_key, exists: entry[:exists],
            value_hash: entry[:value] ? Digest::SHA256.hexdigest(entry[:value].to_s) : nil,
            byte_size: entry[:byte_size]
          }
        end

        def cache_after_snapshot(cache_key, entry)
          {
            cache_key: cache_key,
            exists: entry ? entry[:exists] : false,
            cleared: entry.nil? || !entry[:exists]
          }
        end

        def capture_flag_snapshot(phase, params)
          flag_name = params[:flag_name]
          return nil unless flag_name

          flag = Wild::AdminTools.configuration.flag_adapter.read_flag(flag_name)
          return nil unless flag

          phase == :before ? flag_before_snapshot(flag) : flag_after_snapshot(flag)
        end

        def flag_before_snapshot(flag)
          { flag_name: flag[:name], enabled: flag[:enabled], percentage: flag[:percentage], actors: flag[:actors] }
        end

        def flag_after_snapshot(flag)
          { flag_name: flag[:name], enabled: flag[:enabled], changed_at: Time.now.utc.iso8601 }
        end
      end
    end
  end
end
