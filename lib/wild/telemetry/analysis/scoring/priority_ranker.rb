# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Scoring
        # Sorts gaps by severity descending and assigns a rank (1 = most critical).
        class PriorityRanker
          def rank(gaps)
            sorted = gaps.sort
            sorted.each_with_index.map do |gap, index|
              { rank: index + 1, gap: gap }
            end
          end

          # Returns gaps sorted by severity descending (highest first).
          def sort(gaps)
            gaps.sort
          end
        end
      end
    end
  end
end
