# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Recommendations
        # Enriches gaps that lack recommendations with generated ones based on gap type.
        class Engine
          TEMPLATES = {
            denial: "Review permission grants for %<action>s. " \
                    "Denial rate %<rate>s indicates callers need additional capabilities.",
            failure: "Investigate error handling for %<action>s. " \
                     "High failure rate suggests fragile integration or missing error recovery.",
            latency: "Profile and optimize %<action>s. " \
                     "Latency exceeds acceptable thresholds and may impact user experience.",
            utilization: "Evaluate whether %<action>s provides sufficient value given its low usage. " \
                         "Consider deprecation or improved documentation.",
            coverage: "Expand capability usage for %<action>s. " \
                      "Low coverage may indicate discovery or documentation gaps.",
            pattern: "Investigate and resolve the recurring pattern involving %<action>s. " \
                     "Patterns indicate systemic issues requiring architectural attention."
          }.freeze

          def enrich(gaps)
            gaps.map { |gap| gap.recommendation ? gap : fill_recommendation(gap) }
          end

          private

          def fill_recommendation(gap)
            template = TEMPLATES.fetch(gap.type, "Review %<action>s for improvement opportunities.")
            rec = format(template, action: gap.action, rate: format_evidence_rate(gap))

            Models::Gap.new(
              type: gap.type,
              action: gap.action,
              severity: gap.severity,
              evidence: gap.evidence,
              description: gap.description,
              recommendation: rec
            )
          end

          def format_evidence_rate(gap)
            evidence = gap.evidence
            return "unknown" unless evidence.is_a?(Hash)

            rate_key = evidence.keys.grep(/rate/).first
            return "unknown" unless rate_key

            "#{(evidence[rate_key].to_f * 100).round(1)}%"
          end
        end
      end
    end
  end
end
