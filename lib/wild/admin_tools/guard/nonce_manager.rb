# frozen_string_literal: true

require "digest"
require "json"
require "securerandom"

module Wild
  module AdminTools
    module Guard
      # Manages nonce lifecycle: generation and secure single-use validation.
      #
      # Every generated nonce is cryptographically bound to a specific action,
      # parameter set, and caller identity. Clients receive only opaque failure
      # reasons to prevent oracle attacks (Security Decision 8).
      class NonceManager
        NONCE_PREFIX = "wnc_"
        MIN_TTL = 10
        MAX_TTL = 120
        CLIENT_FAILURE_REASON = "nonce_invalid"

        attr_reader :store

        def initialize(store: NonceStore.new)
          @store = store
        end

        def generate(action_name, params, caller_id, ttl_seconds: 30)
          ttl = ttl_seconds.clamp(MIN_TTL, MAX_TTL)
          nonce = "#{NONCE_PREFIX}#{SecureRandom.hex(16)}"
          entry = NonceEntry.new(
            nonce: nonce,
            binding_hash: compute_binding_hash(action_name, params, caller_id),
            action_name: action_name,
            caller_id: caller_id,
            expires_at: Time.now.utc + ttl
          )
          @store.store(entry)
          nonce
        end

        def validate_and_consume!(nonce, action_name, params, caller_id)
          entry = @store.fetch(nonce)
          return failure("nonce_not_found") unless entry

          if entry.expires_at < Time.now.utc
            @store.remove(nonce)
            return failure("nonce_expired")
          end

          return failure("nonce_already_used") if entry.consumed

          internal_reason = binding_failure_reason(entry, action_name, params, caller_id)
          return failure(internal_reason) if internal_reason

          @store.consume!(nonce)
          { valid: true }
        end

        private

        def compute_binding_hash(action_name, params, caller_id)
          sorted_params_json = params.sort.to_h.to_json
          Digest::SHA256.hexdigest("#{action_name}|#{sorted_params_json}|#{caller_id}")
        end

        def binding_failure_reason(entry, action_name, params, caller_id)
          return "nonce_action_mismatch" unless entry.action_name == action_name
          return "nonce_identity_mismatch" unless entry.caller_id == caller_id

          expected = compute_binding_hash(action_name, params, caller_id)
          return "nonce_parameter_mismatch" unless entry.binding_hash == expected

          nil
        end

        def failure(internal_reason)
          { valid: false, client_reason: CLIENT_FAILURE_REASON, internal_reason: internal_reason }
        end
      end
    end
  end
end
