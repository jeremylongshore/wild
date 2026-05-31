# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class OrphanAnalyzer
          def analyze(capabilities, grants)
            cap_names = capabilities.to_set(&:name)
            findings = []

            findings.concat(orphan_capability_findings(capabilities, grants))
            findings.concat(missing_grant_capability_findings(grants, cap_names))
          end

          private

          def orphan_capability_findings(capabilities, grants)
            all_grant_patterns = grants.flat_map(&:capabilities)

            capabilities
              .reject { |cap| all_grant_patterns.any? { |pattern| WildcardMatcher.matches?(pattern, cap.name) } }
              .map { |cap| orphan_finding(cap) }
          end

          def orphan_finding(cap)
            Models::Finding.new(
              type: :orphan_capability,
              severity: :info,
              message: "Capability '#{cap.name}' is defined but never granted to any caller",
              evidence: { capability: cap.name, risk_level: cap.risk_level, tags: cap.tags }
            )
          end

          def missing_grant_capability_findings(grants, cap_names)
            findings = []
            grants.each do |grant|
              grant.capabilities.each do |pattern|
                next if pattern.include?("*")
                next if cap_names.include?(pattern)

                findings << Models::Finding.new(
                  type: :grant_references_missing_capability,
                  severity: :error,
                  message: "Grant for '#{grant.caller_id}' references capability '#{pattern}' " \
                           "which does not exist in capabilities.yml",
                  evidence: { caller_id: grant.caller_id, capability: pattern }
                )
              end
            end
            findings
          end
        end
      end
    end
  end
end
