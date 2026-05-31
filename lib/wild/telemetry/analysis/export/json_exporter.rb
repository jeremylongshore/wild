# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Export
        class JsonExporter
          # Returns a JSON string for the given GapReport.
          def export(report)
            JSON.generate(report.to_h)
          end

          # Writes JSON to path and returns path.
          def write(report, path)
            content = export(report)
            File.write(path, content)
            path
          end
        end
      end
    end
  end
end
