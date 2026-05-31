# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Schema
        class Validator
          VALID_EVENT_TYPES = %w[action.completed gate.evaluated rate_limit.checked].freeze
          VALID_OUTCOMES = %w[success denied error preview rate_limited].freeze
          REQUIRED_FIELDS = %i[event_type timestamp caller_id action outcome].freeze
          ISO8601_PATTERN = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/

          def validate(event)
            errors = []
            h = normalize_keys(event)

            validate_required_fields(h, errors)
            validate_event_type(h[:event_type], errors)
            validate_outcome(h[:outcome], errors)
            validate_timestamp(h[:timestamp], errors)
            validate_duration_ms(h[:duration_ms], errors)
            validate_metadata(h[:metadata], errors)

            [errors.empty?, errors]
          end

          private

          def normalize_keys(event)
            return event.transform_keys(&:to_sym) if event.respond_to?(:transform_keys)

            {}
          end

          def validate_required_fields(event_hash, errors)
            REQUIRED_FIELDS.each do |field|
              value = event_hash[field]
              errors << "#{field} is required" if value.nil? || (value.respond_to?(:empty?) && value.empty?)
            end
          end

          def validate_event_type(event_type, errors)
            return if event_type.nil?

            errors << "invalid event_type: #{event_type}" unless VALID_EVENT_TYPES.include?(event_type.to_s)
          end

          def validate_outcome(outcome, errors)
            return if outcome.nil?

            errors << "invalid outcome: #{outcome}" unless VALID_OUTCOMES.include?(outcome.to_s)
          end

          def validate_timestamp(timestamp, errors)
            return if timestamp.nil?

            errors << "invalid timestamp format" unless timestamp.to_s.match?(ISO8601_PATTERN)
          end

          def validate_duration_ms(duration_ms, errors)
            return if duration_ms.nil?

            errors << "duration_ms must be numeric" unless duration_ms.is_a?(Numeric)
          end

          def validate_metadata(metadata, errors)
            return if metadata.nil?

            errors << "metadata must be a Hash" unless metadata.is_a?(Hash)
          end
        end
      end
    end
  end
end
