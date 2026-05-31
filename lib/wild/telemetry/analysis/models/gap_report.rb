# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class GapReport
          attr_reader :header, :gaps, :generated_at

          def initialize(header:, gaps:, generated_at: Time.now.utc.iso8601)
            @header = header
            @gaps = gaps.sort
            @generated_at = generated_at
          end

          def summary
            {
              total_gaps: gaps.size,
              by_type: gaps.group_by(&:type).transform_values(&:count),
              severity_avg: severity_average,
              high_severity_count: high_severity_count,
              top_actions: top_actions
            }
          end

          def gaps_of_type(type)
            gaps.select { |g| g.type == type.to_sym }
          end

          def to_h
            {
              header: header&.to_h,
              generated_at: generated_at,
              summary: summary,
              gaps: gaps.map(&:to_h)
            }
          end

          private

          def severity_average
            return 0.0 if gaps.empty?

            (gaps.sum(&:severity) / gaps.size).round(4)
          end

          def high_severity_count
            gaps.count { |g| g.severity >= 0.7 }
          end

          def top_actions
            gaps
              .group_by(&:action)
              .transform_values { |gs| gs.map(&:severity).max }
              .sort_by { |_, max_sev| -max_sev }
              .first(5)
              .map { |action, max_sev| { action: action, max_severity: max_sev } }
          end
        end
      end
    end
  end
end
