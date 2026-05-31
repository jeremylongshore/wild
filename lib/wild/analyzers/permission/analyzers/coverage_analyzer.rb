# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class CoverageAnalyzer
          def analyze(capabilities, grants)
            cap_names = capabilities.map(&:name)
            grants.map(&:caller_id).uniq.map do |caller_id|
              build_coverage_report(caller_id, grants.select { |g| g.caller_id == caller_id }, cap_names)
            end
          end

          def coverage_for(caller_id, capabilities, grants)
            cap_names = capabilities.map(&:name)
            build_coverage_report(caller_id, grants.select { |g| g.caller_id == caller_id }, cap_names)
          end

          private

          def build_coverage_report(caller_id, caller_grants, cap_names)
            grant_chain = build_grant_chain(caller_grants, cap_names)
            Models::CoverageReport.new(
              caller_id: caller_id,
              granted_capabilities: grant_chain.keys,
              denied_capabilities: cap_names - grant_chain.keys,
              grant_chain: grant_chain
            )
          end

          def build_grant_chain(caller_grants, cap_names)
            caller_grants.each_with_object({}) do |grant, chain|
              WildcardMatcher.resolve_patterns(grant.capabilities, cap_names).each do |cap_name|
                chain[cap_name] ||= []
                chain[cap_name] << grant
              end
            end
          end
        end
      end
    end
  end
end
