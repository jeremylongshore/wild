# frozen_string_literal: true

module Wild
  module Introspection
    module Adapter
      module ConnectionManager
        class << self
          def connection
            if replica_configured?
              replica_connection
            else
              ActiveRecord::Base.connection
            end
          end

          def configure(replica_url:)
            @replica_url = replica_url
            @replica_connection = nil
          end

          def replica_configured?
            @replica_url.present?
          end

          def reset!
            @replica_url = nil
            @replica_connection = nil
          end

          private

          def replica_connection
            @replica_connection ||= establish_replica
          end

          def establish_replica
            ActiveRecord::Base.establish_connection(@replica_url)
            ActiveRecord::Base.connection
          end
        end
      end
    end
  end
end
