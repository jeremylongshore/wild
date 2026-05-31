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

          # Cycle detection via iterative tri-color DFS over the prerequisite
          # graph (Fowler review findings 1 + 10). The previous implementation
          # used a path-local `visited` array plus a `depth > max_prerequisite_depth`
          # short-circuit that returned a FAKE cycle path for any acyclic chain
          # deeper than the limit — inventing critical findings. There is no depth
          # limit here: a back-edge to a node that is still on the DFS stack (GRAY)
          # is the *only* signal of a real cycle. Each distinct cycle is reported
          # exactly once (deduped by a rotation-invariant signature), instead of
          # once per node lying on it.
          #
          # Colors: WHITE = unvisited (absent from @color), GRAY = on the current
          # DFS stack, BLACK = fully explored. Iterative (explicit frame stack) so
          # a pathologically deep acyclic chain cannot blow the Ruby call stack.
          def circular_findings(cap_index)
            color = {}
            reported = {}
            findings = []
            cap_index.each_key do |root|
              next unless color[root].nil? # already BLACK/GRAY from a prior root

              detect_cycles_from(root, cap_index, color, reported, findings)
            end
            findings
          end

          # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity -- explicit-stack DFS; the state machine reads as one unit
          def detect_cycles_from(root, cap_index, color, reported, findings)
            # Each frame: [name, index-into-its-prerequisites]. `path` mirrors the
            # GRAY stack for cycle reconstruction.
            stack = [[root, 0]]
            path = []
            color[root] = :gray
            path.push(root)

            until stack.empty?
              name, idx = stack.last
              prereqs = cap_index[name]&.prerequisites || []

              if idx >= prereqs.length
                # Exhausted: this node is fully explored.
                color[name] = :black
                path.pop
                stack.pop
                next
              end

              stack.last[1] += 1
              prereq = prereqs[idx]
              next if cap_index[prereq].nil? # undefined prereq — not a cycle (missing_prerequisite covers it)

              case color[prereq]
              when :gray then record_cycle(prereq, path, reported, findings)
              when nil # WHITE — descend
                color[prereq] = :gray
                path.push(prereq)
                stack.push([prereq, 0])
              end
              # BLACK → already fully explored, no cycle through it
            end
          end
          # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

          # A GRAY back-edge to `prereq` closes a cycle: the slice of `path` from
          # `prereq` to the end, plus `prereq` again to show closure.
          def record_cycle(prereq, path, reported, findings)
            cycle = path[path.index(prereq)..] + [prereq] # display form, e.g. [a, b, a]
            key = canonical_signature(cycle[0...-1]) # rotation-invariant dedup key
            return if reported[key]

            reported[key] = true
            findings << Models::Finding.new(
              type: :circular_prerequisite,
              severity: :critical,
              message: "Circular prerequisite chain detected: #{cycle.join(" -> ")}",
              evidence: { capability: cycle.first, cycle_path: cycle }
            )
          end

          # Rotation-invariant signature so the same ring entered at any node —
          # a->b->a vs b->a->b — dedupes to one cycle. Rotate the node list to
          # start at its minimum element, then join.
          def canonical_signature(nodes)
            nodes.rotate(nodes.index(nodes.min)).join(">")
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
