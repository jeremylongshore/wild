# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class ExportHeader
          attr_reader :export_type, :schema_version, :exported_at, :source_id,
                      :time_range, :record_counts

          def initialize(data)
            @export_type = data["export_type"]
            @schema_version = data["schema_version"]
            @exported_at = data["exported_at"]
            @source_id = data["source_id"]
            @time_range = data["time_range"] || {}
            @record_counts = data["record_counts"] || {}
          end

          def valid?
            export_type == "session_telemetry" && !schema_version.nil? && !source_id.nil?
          end

          def to_h
            {
              export_type: export_type,
              schema_version: schema_version,
              exported_at: exported_at,
              source_id: source_id,
              time_range: time_range,
              record_counts: record_counts
            }
          end
        end
      end
    end
  end
end
