# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class ConsistencyAnalyzer
          def analyze(capabilities, grants)
            capability_names = capabilities.to_set(&:name)
            findings = []

            grants.each do |grant|
              grant.capabilities.each do |pattern|
                next if pattern.include?("*")
                next if capability_names.include?(pattern)

                findings << Models::Finding.new(
                  type: :missing_reference,
                  severity: :error,
                  message: "Grant for '#{grant.caller_id}' references unknown capability '#{pattern}'",
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
