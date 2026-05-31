# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      class JobExecutor < Base
        ACTION_MAP = {
          "inspect_job" => { preview: :preview_inspect_job, execute: :execute_inspect_job, operation: "read" },
          "list_failed_jobs" => { preview: :preview_list_failed_jobs, execute: :execute_list_failed_jobs,
                                  operation: "read" },
          "list_queues" => { preview: :preview_list_queues, execute: :execute_list_queues, operation: "read" },
          "retry_job" => { preview: :preview_retry_job, execute: :execute_retry_job, operation: "mutate" },
          "retry_jobs_by_filter" => { preview: :preview_retry_jobs_by_filter, execute: :execute_retry_jobs_by_filter,
                                      operation: "mutate" },
          "discard_job" => { preview: :preview_discard_job, execute: :execute_discard_job,
                             operation: "mutate_destructive" },
          "discard_jobs_by_filter" => { preview: :preview_discard_jobs_by_filter,
                                        execute: :execute_discard_jobs_by_filter,
                                        operation: "mutate_destructive" }
        }.freeze

        private

        def adapter
          Wild::AdminTools.configuration.job_adapter
        end

        # --- inspect_job ---

        def preview_inspect_job(params)
          job = adapter.find_job(params[:job_id])
          { job: job }
        end

        def execute_inspect_job(params)
          adapter.find_job(params[:job_id])
        end

        # --- list_failed_jobs ---

        def preview_list_failed_jobs(params)
          jobs = adapter.list_failed_jobs(**params.slice(:queue_name, :error_class, :limit))
          { jobs: jobs, count: jobs.size }
        end

        def execute_list_failed_jobs(params)
          jobs = adapter.list_failed_jobs(**params.slice(:queue_name, :error_class, :limit))
          { jobs: jobs, count: jobs.size }
        end

        # --- list_queues ---

        def preview_list_queues(_params)
          queues = adapter.list_queues
          { queues: queues }
        end

        def execute_list_queues(_params)
          { queues: adapter.list_queues }
        end

        # --- retry_job ---

        def preview_retry_job(params)
          job = adapter.find_job(params[:job_id])
          { job: job, will_retry: !job.nil? }
        end

        def execute_retry_job(params)
          adapter.retry_job!(params[:job_id])
        end

        # --- retry_jobs_by_filter ---

        def preview_retry_jobs_by_filter(params)
          filter = params[:filter] || {}
          count = adapter.count_matching_jobs(**filter.transform_keys(&:to_sym))
          { estimated_affected: count, filter: filter, max_count: params.fetch(:max_count, 10) }
        end

        def execute_retry_jobs_by_filter(params)
          filter = params[:filter] || {}
          max_count = params.fetch(:max_count, 10)
          adapter.retry_jobs!(**filter.transform_keys(&:to_sym), max_count: max_count)
        end

        # --- discard_job ---

        def preview_discard_job(params)
          job = adapter.find_job(params[:job_id])
          { job: job, will_discard: !job.nil? }
        end

        def execute_discard_job(params)
          adapter.discard_job!(params[:job_id])
        end

        # --- discard_jobs_by_filter ---

        def preview_discard_jobs_by_filter(params)
          filter = params[:filter] || {}
          count = adapter.count_matching_jobs(**filter.transform_keys(&:to_sym))
          { estimated_affected: count, filter: filter, max_count: params.fetch(:max_count, 10) }
        end

        def execute_discard_jobs_by_filter(params)
          filter = params[:filter] || {}
          max_count = params.fetch(:max_count, 10)
          adapter.discard_jobs!(**filter.transform_keys(&:to_sym), max_count: max_count)
        end
      end
    end
  end
end
