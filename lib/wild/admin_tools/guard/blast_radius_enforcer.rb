# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      # Enforces blast radius caps on mutating operations.
      # Read operations always pass; the cap is informational only for reads.
      class BlastRadiusEnforcer
        READ_OPERATIONS = %w[read].freeze

        def check(action_config, estimated_count)
          cap = action_config["blast_radius_cap"]
          operation = action_config["operation"]

          return allowed_result(estimated_count, cap) if read_operation?(operation)
          # Defense in depth: PolicyConfig validates every merged action against
          # hard_ceilings before it is ever handed to this class, but a nil or
          # non-Integer cap must still deny explicitly here rather than raise
          # (or silently pass) if that invariant is ever violated by a caller
          # that builds action_config another way (security-review follow-up
          # on f-l10-6, PR #73).
          return invalid_cap_result(estimated_count, cap) unless cap.is_a?(Integer)
          return allowed_result(estimated_count, cap) if within_cap?(estimated_count, cap)

          denied_result(estimated_count, cap)
        end

        private

        def read_operation?(operation)
          READ_OPERATIONS.include?(operation)
        end

        def within_cap?(estimated_count, cap)
          estimated_count <= cap
        end

        def allowed_result(estimated_count, cap)
          { allowed: true, estimated_count: estimated_count, cap: cap }
        end

        def denied_result(estimated_count, cap)
          {
            allowed: false,
            estimated_count: estimated_count,
            cap: cap,
            reason: "blast_radius_exceeded"
          }
        end

        def invalid_cap_result(estimated_count, cap)
          {
            allowed: false,
            estimated_count: estimated_count,
            cap: cap,
            reason: "missing_or_invalid_blast_radius_cap"
          }
        end
      end
    end
  end
end
