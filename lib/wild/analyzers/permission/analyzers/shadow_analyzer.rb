# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class ShadowAnalyzer
          def analyze(capabilities, grants)
            cap_names = capabilities.to_set(&:name)
            grants.map(&:caller_id).uniq.flat_map do |caller_id|
              find_shadows(caller_id, grants.select { |g| g.caller_id == caller_id }, cap_names)
            end
          end

          private

          def find_shadows(caller_id, caller_grants, cap_names)
            caller_grants.flat_map do |grant|
              shadowed_explicit_caps(grant, caller_grants, cap_names).map do |cap_name, shadowing|
                shadow_finding(caller_id, cap_name, shadowing)
              end
            end
          end

          def shadowed_explicit_caps(grant, caller_grants, cap_names)
            explicit_caps(grant, cap_names).filter_map do |cap_name|
              shadowing = shadowing_wildcards(cap_name, grant, caller_grants)
              [cap_name, shadowing] unless shadowing.empty?
            end
          end

          def explicit_caps(grant, cap_names)
            grant.capabilities.reject { |p| p.include?("*") }.select { |c| cap_names.include?(c) }
          end

          def shadowing_wildcards(cap_name, original_grant, caller_grants)
            caller_grants
              .reject { |g| g.equal?(original_grant) }
              .flat_map(&:wildcard_capabilities)
              .select { |pattern| WildcardMatcher.matches?(pattern, cap_name) }
              .uniq
          end

          def shadow_finding(caller_id, cap_name, shadowing_patterns)
            Models::Finding.new(
              type: :shadowed_grant,
              severity: :warning,
              message: "Explicit grant of '#{cap_name}' to '#{caller_id}' is shadowed by " \
                       "wildcard grant(s): #{shadowing_patterns.inspect}",
              evidence: { caller_id: caller_id, capability: cap_name, shadowed_by: shadowing_patterns }
            )
          end
        end
      end
    end
  end
end
