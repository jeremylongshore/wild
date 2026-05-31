# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class TelemetryRecord
          attr_reader :record_type, :raw

          def initialize(data)
            @record_type = data["record_type"]
            @raw = data
          end

          def to_h
            raw.dup
          end
        end
      end
    end
  end
end
