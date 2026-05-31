# frozen_string_literal: true

module Wild
  module Analyzers
    module Permission
      module Analyzers
        class PrerequisiteAnalyzer
          def initialize(config = Wild.config.analyzers.permission)
            @config = config
          end

          def analyze(capabilities, grants)
            cap_index = capabilities.index_by { |c| c.name } # rubocop:disable Style/SymbolProc
            cap_names = cap_index.keys.to_set
            findings = []

            findings.concat(missing_prereq_findings(capabilities, cap_names))
            findings.concat(circular_findings(cap_index))
            findings.concat(unsatisfied_grant_findings(grants, cap_index, cap_names))
          end

          private

          def missing_prereq_findings(capabilities, cap_names)
            capabilities.flat_map do |cap|
              cap.prerequisites.filter_map do |prereq|
                next if cap_names.include?(prereq)

                Models::Finding.new(
                  type: :missing_prerequisite,
                  severity: :error,
                  message: "Capability '#{cap.name}' requires prerequisite '#{prereq}' which is not defined",
                  evidence: { capability: cap.name, missing_prerequisite: prereq }
                )
              end
            end
          end

          def circular_findings(cap_index)
            findings = []
            cap_index.each_key do |name|
              path = detect_cycle(name, cap_index, [], 0)
              next unless path

              findings << Models::Finding.new(
                type: :circular_prerequisite,
                severity: :critical,
                message: "Circular prerequisite chain detected involving '#{name}': #{path.join(" -> ")}",
                evidence: { capability: name, cycle_path: path }
              )
            end
            findings
          end

          def detect_cycle(name, cap_index, visited, depth)
            return [name, "..."] if depth > @config.max_prerequisite_depth
            return nil if cap_index[name].nil?
            return [name] if visited.include?(name)

            cap_index[name].prerequisites.each do |prereq|
              result = detect_cycle(prereq, cap_index, visited + [name], depth + 1)
              return [name] + result if result
            end
            nil
          end

          def unsatisfied_grant_findings(grants, cap_index, cap_names)
            grants.flat_map do |grant|
              resolved = WildcardMatcher.resolve_patterns(grant.capabilities, cap_names.to_a)
              resolved.flat_map { |cap_name| unsatisfied_prereqs(grant, cap_name, cap_index, cap_names) }
            end
          end

          def unsatisfied_prereqs(grant, cap_name, cap_index, cap_names)
            cap = cap_index[cap_name]
            return [] unless cap

            cap.prerequisites.filter_map do |prereq|
              next if cap_names.include?(prereq)

              Models::Finding.new(
                type: :unsatisfiable_prerequisite,
                severity: :error,
                message: "Grant for '#{grant.caller_id}' includes '#{cap_name}' but " \
                         "its prerequisite '#{prereq}' is not defined",
                evidence: { caller_id: grant.caller_id, capability: cap_name, missing_prerequisite: prereq }
              )
            end
          end
        end
      end
    end
  end
end
