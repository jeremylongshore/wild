# frozen_string_literal: true

require "time"

module Wild
  module AdminTools
    module TestSupport
      class TestJobAdapter < Executor::Adapters::JobAdapter
        attr_reader :calls

        def initialize
          super
          @calls = []
          @jobs = {}
          @queues = []
        end

        def seed_job(job_id, attrs = {})
          @jobs[job_id] = {
            job_id: job_id,
            status: "dead",
            queue: "default",
            error_class: "RuntimeError",
            error_message: "something went wrong",
            failed_at: Time.now.utc.iso8601,
            retry_count: 0,
            enqueued_at: nil,
            discarded_at: nil,
            created_at: Time.now.utc.iso8601,
            class: "SomeJob"
          }.merge(attrs)
        end

        def seed_queue(name, size: 0, latency: 0.0)
          @queues << { name: name, size: size, latency: latency }
        end

        def find_job(job_id)
          @calls << { method: :find_job, args: [job_id] }
          @jobs[job_id]
        end

        def list_failed_jobs(queue_name: nil, error_class: nil, limit: 50)
          @calls << { method: :list_failed_jobs,
                      args: { queue_name: queue_name, error_class: error_class, limit: limit } }
          jobs = @jobs.values.select { |j| j[:status] == "dead" }
          jobs = jobs.select { |j| j[:queue] == queue_name } if queue_name
          jobs = jobs.select { |j| j[:error_class] == error_class } if error_class
          jobs.first(limit)
        end

        def list_queues
          @calls << { method: :list_queues, args: [] }
          @queues
        end

        def count_matching_jobs(queue_name: nil, error_class: nil, job_class: nil, **_rest)
          @calls << { method: :count_matching_jobs,
                      args: { queue_name: queue_name, error_class: error_class, job_class: job_class } }
          jobs = @jobs.values
          jobs = jobs.select { |j| j[:queue] == queue_name } if queue_name
          jobs = jobs.select { |j| j[:error_class] == error_class } if error_class
          jobs = jobs.select { |j| j[:class] == job_class } if job_class
          jobs.size
        end

        def retry_job!(job_id)
          @calls << { method: :retry_job!, args: [job_id] }
          job = @jobs[job_id]
          raise Wild::AdminTools::AdapterError, "Job #{job_id} not found" unless job

          job[:status] = "enqueued"
          job[:enqueued_at] = Time.now.utc.iso8601
          { job_id: job_id, retried: true }
        end

        def retry_jobs!(max_count: 10, **filter)
          @calls << { method: :retry_jobs!, args: { max_count: max_count, **filter } }
          matching = filter_jobs(**filter).first(max_count)
          matching.each do |j|
            j[:status] = "enqueued"
            j[:enqueued_at] = Time.now.utc.iso8601
          end
          { retried_count: matching.size, filter: filter }
        end

        def discard_job!(job_id)
          @calls << { method: :discard_job!, args: [job_id] }
          job = @jobs[job_id]
          raise Wild::AdminTools::AdapterError, "Job #{job_id} not found" unless job

          job[:status] = "discarded"
          job[:discarded_at] = Time.now.utc.iso8601
          { job_id: job_id, discarded: true }
        end

        def discard_jobs!(max_count: 10, **filter)
          @calls << { method: :discard_jobs!, args: { max_count: max_count, **filter } }
          matching = filter_jobs(**filter).first(max_count)
          matching.each do |j|
            j[:status] = "discarded"
            j[:discarded_at] = Time.now.utc.iso8601
          end
          { discarded_count: matching.size, filter: filter }
        end

        def write_methods_called
          @calls.select { |c| c[:method].to_s.end_with?("!") }
        end

        private

        def filter_jobs(queue_name: nil, error_class: nil, job_class: nil, **_rest)
          jobs = @jobs.values
          jobs = jobs.select { |j| j[:queue] == queue_name } if queue_name
          jobs = jobs.select { |j| j[:error_class] == error_class } if error_class
          jobs = jobs.select { |j| j[:class] == job_class } if job_class
          jobs
        end
      end

      class TestCacheAdapter < Executor::Adapters::CacheAdapter
        attr_reader :calls

        def initialize
          super
          @calls = []
          @store = {}
        end

        def seed_key(cache_key, value, byte_size: nil)
          @store[cache_key] = {
            cache_key: cache_key,
            exists: true,
            value: value,
            byte_size: byte_size || value.to_s.bytesize
          }
        end

        def read_key(cache_key)
          @calls << { method: :read_key, args: [cache_key] }
          @store[cache_key] || { cache_key: cache_key, exists: false, value: nil, byte_size: 0 }
        end

        def list_keys(prefix:, limit: 50)
          @calls << { method: :list_keys, args: { prefix: prefix, limit: limit } }
          @store.keys
                .select { |k| k.start_with?(prefix) }
                .first(limit)
                .map { |k| { cache_key: k } }
        end

        def cache_stats
          @calls << { method: :cache_stats, args: [] }
          { total_keys: @store.size, total_bytes: @store.values.sum { |v| v[:byte_size] } }
        end

        def count_matching_keys(pattern)
          @calls << { method: :count_matching_keys, args: [pattern] }
          @store.keys.count { |k| k.start_with?(pattern) }
        end

        def delete_key!(cache_key)
          @calls << { method: :delete_key!, args: [cache_key] }
          existed = @store.key?(cache_key)
          @store.delete(cache_key)
          { cache_key: cache_key, deleted: existed }
        end

        def delete_matching!(pattern)
          @calls << { method: :delete_matching!, args: [pattern] }
          keys = @store.keys.select { |k| k.start_with?(pattern) }
          keys.each { |k| @store.delete(k) }
          { pattern: pattern, deleted_count: keys.size }
        end

        def write_methods_called
          @calls.select { |c| c[:method].to_s.end_with?("!") }
        end
      end

      class TestFlagAdapter < Executor::Adapters::FlagAdapter
        attr_reader :calls

        def initialize
          super
          @calls = []
          @flags = {}
        end

        def seed_flag(flag_name, attrs = {})
          @flags[flag_name] = {
            name: flag_name,
            enabled: false,
            percentage: nil,
            actors: []
          }.merge(attrs)
        end

        def read_flag(flag_name)
          @calls << { method: :read_flag, args: [flag_name] }
          @flags[flag_name]
        end

        def list_flags(filter: nil, enabled_only: false, limit: 100)
          @calls << { method: :list_flags, args: { filter: filter, enabled_only: enabled_only, limit: limit } }
          flags = @flags.values
          flags = flags.select { |f| f[:name].include?(filter) } if filter
          flags = flags.select { |f| f[:enabled] } if enabled_only
          flags.first(limit)
        end

        def toggle_flag!(flag_name, enabled)
          @calls << { method: :toggle_flag!, args: [flag_name, enabled] }
          flag = @flags[flag_name]
          raise Wild::AdminTools::AdapterError, "Flag #{flag_name} not found" unless flag

          flag[:enabled] = enabled
          { flag_name: flag_name, enabled: enabled }
        end

        def enable_for_actor!(flag_name, actor_type, actor_id)
          @calls << { method: :enable_for_actor!, args: [flag_name, actor_type, actor_id] }
          flag = @flags[flag_name]
          raise Wild::AdminTools::AdapterError, "Flag #{flag_name} not found" unless flag

          flag[:actors] << "#{actor_type};#{actor_id}"
          { flag_name: flag_name, actor_type: actor_type, actor_id: actor_id, enabled: true }
        end

        def disable_for_actor!(flag_name, actor_type, actor_id)
          @calls << { method: :disable_for_actor!, args: [flag_name, actor_type, actor_id] }
          flag = @flags[flag_name]
          raise Wild::AdminTools::AdapterError, "Flag #{flag_name} not found" unless flag

          flag[:actors].delete("#{actor_type};#{actor_id}")
          { flag_name: flag_name, actor_type: actor_type, actor_id: actor_id, enabled: false }
        end

        def enable_percentage!(flag_name, percentage)
          @calls << { method: :enable_percentage!, args: [flag_name, percentage] }
          flag = @flags[flag_name]
          raise Wild::AdminTools::AdapterError, "Flag #{flag_name} not found" unless flag

          flag[:percentage] = percentage
          { flag_name: flag_name, percentage: percentage }
        end

        def delete_flag!(flag_name)
          @calls << { method: :delete_flag!, args: [flag_name] }
          raise Wild::AdminTools::AdapterError, "Flag #{flag_name} not found" unless @flags.key?(flag_name)

          @flags.delete(flag_name)
          { flag_name: flag_name, deleted: true }
        end

        def write_methods_called
          @calls.select { |c| c[:method].to_s.end_with?("!") }
        end
      end
    end
  end
end
