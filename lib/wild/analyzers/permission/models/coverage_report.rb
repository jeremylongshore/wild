# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Models
        class CoverageReport
          attr_reader :caller_id, :granted_capabilities, :denied_capabilities, :grant_chain

          # grant_chain: Hash { capability_name => [Grant, ...] }
          def initialize(caller_id:, granted_capabilities:, denied_capabilities:, grant_chain:)
            @caller_id = caller_id
            @granted_capabilities = granted_capabilities.freeze
            @denied_capabilities = denied_capabilities.freeze
            @grant_chain = grant_chain.freeze
          end

          def coverage_ratio
            total = granted_capabilities.size + denied_capabilities.size
            return 0.0 if total.zero?

            granted_capabilities.size.to_f / total
          end
        end
      end
    end
  end
end
