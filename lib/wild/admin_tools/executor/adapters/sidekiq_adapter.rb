# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class SidekiqAdapter < JobAdapter
          def find_job(job_id)
            require_sidekiq!
            job = Sidekiq::DeadSet.new.find_job(job_id)
            return nil unless job

            serialize_job_full(job)
          end

          def list_failed_jobs(queue_name: nil, error_class: nil, limit: 50)
            require_sidekiq!
            jobs = Sidekiq::DeadSet.new.to_a
            jobs = jobs.select { |j| j.queue == queue_name } if queue_name
            jobs = jobs.select { |j| j.item["error_class"] == error_class } if error_class
            jobs.first(limit).map { |j| serialize_job(j) }
          end

          def list_queues
            require_sidekiq!
            Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size, latency: q.latency } }
          end

          def count_matching_jobs(queue_name: nil, error_class: nil, job_class: nil, **_rest)
            require_sidekiq!
            jobs = Sidekiq::DeadSet.new.to_a
            jobs = jobs.select { |j| j.queue == queue_name } if queue_name
            jobs = jobs.select { |j| j.item["error_class"] == error_class } if error_class
            jobs = jobs.select { |j| j.item["class"] == job_class } if job_class
            jobs.size
          end

          def retry_job!(job_id)
            require_sidekiq!
            job = Sidekiq::DeadSet.new.find_job(job_id)
            raise AdapterError, "Job #{job_id} not found" unless job

            job.retry
            { job_id: job_id, retried: true }
          end

          def retry_jobs!(max_count: 10, **filter)
            require_sidekiq!
            jobs = filter_dead_jobs(**filter).first(max_count)
            jobs.each(&:retry)
            { retried_count: jobs.size, filter: filter }
          end

          def discard_job!(job_id)
            require_sidekiq!
            job = Sidekiq::DeadSet.new.find_job(job_id)
            raise AdapterError, "Job #{job_id} not found" unless job

            job.delete
            { job_id: job_id, discarded: true }
          end

          def discard_jobs!(max_count: 10, **filter)
            require_sidekiq!
            jobs = filter_dead_jobs(**filter).first(max_count)
            jobs.each(&:delete)
            { discarded_count: jobs.size, filter: filter }
          end

          private

          def require_sidekiq!
            require "sidekiq/api"
          rescue LoadError
            raise AdapterError, "Sidekiq gem is not available. Add sidekiq to your Gemfile."
          end

          def filter_dead_jobs(queue_name: nil, error_class: nil, job_class: nil, **_rest)
            jobs = Sidekiq::DeadSet.new.to_a
            jobs = jobs.select { |j| j.queue == queue_name } if queue_name
            jobs = jobs.select { |j| j.item["error_class"] == error_class } if error_class
            jobs = jobs.select { |j| j.item["class"] == job_class } if job_class
            jobs
          end

          def serialize_job(job)
            serialize_job_full(job).except(:error_message, :enqueued_at, :created_at)
          end

          def serialize_job_full(job)
            item = job.item
            {
              job_id: job.jid, status: "dead", queue: job.queue,
              error_class: item["error_class"], error_message: item["error_message"],
              failed_at: item["failed_at"], retry_count: item["retry_count"] || 0,
              enqueued_at: item["enqueued_at"], created_at: item["created_at"]
            }
          end
        end
      end
    end
  end
end
