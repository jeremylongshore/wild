# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class JobAdapter
          # Read methods (no side effects)
          def find_job(_job_id)
            raise NotImplementedError, "#{self.class}#find_job"
          end

          def list_failed_jobs(**_options)
            raise NotImplementedError, "#{self.class}#list_failed_jobs"
          end

          def list_queues
            raise NotImplementedError, "#{self.class}#list_queues"
          end

          def count_matching_jobs(**_filter)
            raise NotImplementedError, "#{self.class}#count_matching_jobs"
          end

          # Write methods (mutating — suffixed with !)
          def retry_job!(_job_id)
            raise NotImplementedError, "#{self.class}#retry_job!"
          end

          def retry_jobs!(**_filter)
            raise NotImplementedError, "#{self.class}#retry_jobs!"
          end

          def discard_job!(_job_id)
            raise NotImplementedError, "#{self.class}#discard_job!"
          end

          def discard_jobs!(**_filter)
            raise NotImplementedError, "#{self.class}#discard_jobs!"
          end
        end
      end
    end
  end
end
