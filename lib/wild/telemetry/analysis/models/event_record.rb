# frozen_string_literal: true

module Wild
  module Telemetry
    module Analysis
      module Models
        class EventRecord < TelemetryRecord
          attr_reader :event_type, :timestamp, :caller_id, :action, :outcome,
                      :duration_ms, :metadata

          VALID_OUTCOMES = %w[success denied error preview rate_limited].freeze

          def initialize(data)
            super
            @event_type = data["event_type"]
            @timestamp = data["timestamp"]
            @caller_id = data["caller_id"]
            @action = data["action"]
            @outcome = data["outcome"]
            @duration_ms = data["duration_ms"]
            @metadata = data["metadata"] || {}
          end

          def success?
            outcome == "success"
          end

          def denied?
            outcome == "denied"
          end

          def error?
            outcome == "error"
          end

          def rate_limited?
            outcome == "rate_limited"
          end
        end
      end
    end
  end
end
