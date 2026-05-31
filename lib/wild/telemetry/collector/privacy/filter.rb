# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Privacy
        class Filter
          ALLOWED_TOP_LEVEL_KEYS = %i[event_type timestamp caller_id action outcome duration_ms metadata].freeze

          METADATA_ALLOWLISTS = {
            "action.completed" => %w[category operation phase denial_reason blast_radius_count
                                     confirmation_used].freeze,
            "gate.evaluated" => %w[gate_result capability_checked].freeze,
            "rate_limit.checked" => %w[rate_result current_count limit window_seconds].freeze
          }.freeze

          FORBIDDEN_FIELD_NAMES = %w[
            params parameters arguments args input request_body
            before_state after_state before after snapshot state_before state_after
            nonce confirmation_nonce token confirmation_token
            stack_trace stacktrace backtrace trace error_trace
            jid redis_id execution_id internal_id adapter_id backend_id
          ].freeze

          ALLOWED_VALUE_TYPES = [String, Integer, Float, TrueClass, FalseClass, NilClass].freeze

          def filter(event)
            normalized = normalize(event)
            stripped = strip_top_level(normalized)
            filtered = filter_metadata(stripped)
            sanitize_metadata_values(filtered)
          end

          private

          def normalize(event)
            event.transform_keys(&:to_sym)
          end

          def strip_top_level(event_hash)
            event_hash.slice(*ALLOWED_TOP_LEVEL_KEYS)
          end

          def filter_metadata(event_hash)
            metadata = event_hash[:metadata]
            return event_hash if metadata.nil? || !metadata.is_a?(Hash)

            event_type = event_hash[:event_type].to_s
            allowed_keys = METADATA_ALLOWLISTS.fetch(event_type, [])
            string_keyed = metadata.transform_keys(&:to_s)
            without_forbidden = string_keyed.except(*FORBIDDEN_FIELD_NAMES)
            filtered = without_forbidden.slice(*allowed_keys)
            event_hash.merge(metadata: filtered.transform_keys(&:to_sym))
          end

          def sanitize_metadata_values(event_hash)
            metadata = event_hash[:metadata]
            return event_hash if metadata.nil? || !metadata.is_a?(Hash)

            sanitized = metadata.select { |_, v| ALLOWED_VALUE_TYPES.any? { |t| v.is_a?(t) } }
            event_hash.merge(metadata: sanitized)
          end
        end
      end
    end
  end
end
