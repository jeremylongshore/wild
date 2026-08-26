# frozen_string_literal: true

require "digest"

module Wild
  module Hooks
    module Audit
      # Generic key-pattern parameter sanitizer for audit records.
      #
      # The original wild-admin-tools-mcp gem shipped this as a reusable
      # configurable redactor; the wild-rails-safe-introspection-mcp gem had
      # a per-tool dispatch sanitizer that hardcoded knowledge of three
      # introspection tool names. The honest shared substrate is admin's
      # design — a generic key-walker that redacts secrets, hashes IDs,
      # and recurses into nested hashes.
      #
      # When the introspection namespace's per-tool sanitizer lands in
      # Role 5 PR-N, it can wrap this Sanitizer with its tool-name dispatch
      # rather than reimplementing the redaction logic.
      #
      # Example
      #
      #   sanitizer = Wild::Hooks::Audit::Sanitizer.new
      #   sanitizer.sanitize(password: "hunter2", user_id: 42, name: "Alice")
      #   # => { password: "[REDACTED]", user_id: "[SHA256:abcd1234]", name: "Alice" }
      #
      # Closes the structural-duplication portion of wild-rvv.6.2.
      class Sanitizer
        REDACTED = "[REDACTED]"
        HASHED_PREFIX = "[SHA256:"

        # Substring patterns whose keys redact entirely.
        DEFAULT_REDACT_KEYS = %w[
          password secret token api_key private_key
          ssn social_security credit_card card_number
          email phone address
        ].freeze

        # Substring patterns whose keys get a SHA-256 fingerprint (first
        # 8 hex chars). Useful for correlating audit events across
        # invocations without leaking the underlying identifier.
        DEFAULT_HASH_KEYS = %w[
          job_id actor_id user_id account_id
        ].freeze

        # Exact normalized keys that are operational metadata rather than
        # secrets or stable identities. This prevents substring matching from
        # redacting useful values such as max_tokens (token), email_template
        # (email), and contractor_id (actor_id) while leaving similarly named
        # sensitive fields protected.
        DEFAULT_ALLOW_KEYS = %w[
          max_tokens token_count ip_address email_template contractor_id
        ].freeze

        # Matches a `key=value` token inside a free-form string (e.g. an
        # exception message), so #sanitize_string can redact secret-looking
        # substrings that never passed through #sanitize as a structured
        # hash (f-l01-1 follow-up). Deliberately "=" only, not ":" — a
        # colon is too common in ordinary prose ("connection failed: ...")
        # and would misparse the preceding word as a key.
        KEY_VALUE_PATTERN = /([a-zA-Z][\w-]*)=(\S+)/

        # @param redact_keys [Array<String, Symbol>] substring patterns —
        #   any key containing one of these gets REDACTED
        # @param hash_keys [Array<String, Symbol>] substring patterns —
        #   any key containing one of these gets SHA-256 hashed
        def initialize(redact_keys: DEFAULT_REDACT_KEYS, hash_keys: DEFAULT_HASH_KEYS,
                       allow_keys: DEFAULT_ALLOW_KEYS)
          @redact_keys = Set.new(redact_keys.map { |k| normalize_key(k) })
          @hash_keys   = Set.new(hash_keys.map { |k| normalize_key(k) })
          @allow_keys  = Set.new(allow_keys.map { |k| normalize_key(k) })
        end

        # Sanitize a hash of parameters, returning a new hash with the
        # same key set but transformed values. Recurses into nested hashes
        # and into arrays (including hashes/arrays nested inside them).
        #
        # @param params [Hash, nil]
        # @return [Hash]
        def sanitize(params)
          return {} if params.blank?

          params.each_with_object({}) do |(key, value), out|
            out[key] = sanitize_value(key.to_s, value)
          end
        end

        # Redact secret-looking `key=value`/`key: value` tokens inside a
        # free-form string, using the same redact_keys patterns as #sanitize.
        # Used for values (e.g. exception messages) that were never a
        # structured hash, so per-key redaction never had a chance to run.
        #
        # @param str [String, nil]
        # @return [String, nil]
        def sanitize_string(str)
          return str unless str.is_a?(String)

          str.gsub(KEY_VALUE_PATTERN) do
            key = Regexp.last_match(1)
            value = Regexp.last_match(2)
            if @redact_keys.any? { |rk| normalize_key(key).include?(rk) }
              "#{key}=#{REDACTED}"
            else
              "#{key}=#{value}"
            end
          end
        end

        private

        def sanitize_value(key, value)
          case key_action(normalize_key(key))
          when :allow then value
          when :redact then REDACTED
          when :hash then hash_value(value)
          else sanitize_nested_value(value)
          end
        end

        def key_action(normalized)
          return :allow if @allow_keys.include?(normalized)
          return :redact if @redact_keys.any? { |key| normalized.include?(key) }
          return :hash if @hash_keys.any? { |key| normalized.include?(key) }

          :pass
        end

        def sanitize_nested_value(value)
          return sanitize(value) if value.is_a?(Hash)
          return sanitize_array(value) if value.is_a?(Array)

          value
        end

        def sanitize_array(array)
          array.map do |element|
            case element
            when Hash  then sanitize(element)
            when Array then sanitize_array(element)
            else element
            end
          end
        end

        def hash_value(value)
          digest = Digest::SHA256.hexdigest(value.to_s)[0, 8]
          "#{HASHED_PREFIX}#{digest}]"
        end

        # Normalize a key (or a key-shaped string pulled out of free text)
        # so apiKey / API_KEY / Api-Key / api key all match the "api_key"
        # pattern: downcase and strip everything but letters/digits.
        def normalize_key(value)
          value.to_s.downcase.gsub(/[^a-z0-9]/, "")
        end
      end
    end
  end
end
