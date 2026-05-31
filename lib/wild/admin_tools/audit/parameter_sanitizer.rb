# frozen_string_literal: true

require "digest"

module Wild
  module AdminTools
    module Audit
      class ParameterSanitizer
        REDACTED = "[REDACTED]"
        HASHED_PREFIX = "[SHA256:"

        DEFAULT_REDACT_KEYS = %w[
          password secret token api_key private_key
          ssn social_security credit_card card_number
          email phone address
        ].freeze

        DEFAULT_HASH_KEYS = %w[
          job_id actor_id user_id account_id
        ].freeze

        def initialize(redact_keys: DEFAULT_REDACT_KEYS, hash_keys: DEFAULT_HASH_KEYS)
          @redact_keys = Set.new(redact_keys.map(&:to_s))
          @hash_keys = Set.new(hash_keys.map(&:to_s))
        end

        def sanitize(params)
          return {} if params.blank?

          params.each_with_object({}) do |(key, value), sanitized|
            key_s = key.to_s
            sanitized[key] = sanitize_value(key_s, value)
          end
        end

        private

        def sanitize_value(key, value)
          if @redact_keys.any? { |rk| key.include?(rk) }
            REDACTED
          elsif @hash_keys.any? { |hk| key.include?(hk) }
            hash_value(value)
          elsif value.is_a?(Hash)
            sanitize(value)
          else
            value
          end
        end

        def hash_value(value)
          digest = Digest::SHA256.hexdigest(value.to_s)[0, 8]
          "#{HASHED_PREFIX}#{digest}]"
        end
      end
    end
  end
end
