# frozen_string_literal: true

require "securerandom"

module Wild
  module CapabilityGate
    # Session-scoped state for capability evaluations.
    #
    # Each session caches evaluation results so repeated checks within the
    # same session return the cached result without re-running the full
    # pipeline. Each new session starts clean — no cross-session persistence.
    #
    # Cache key is (caller_id, capability_name). Context is evaluated on
    # first check only; subsequent calls return the cached result. If the
    # caller needs different context, they should use a new session.
    #
    # See 004-AT-ADEC-architecture-decisions.md (Decision 3: session-scoped state).
    class Session
      DEFAULT_TTL = 3600

      attr_reader :id, :created_at

      def initialize(id: nil, ttl: DEFAULT_TTL)
        @id = (id || SecureRandom.uuid).freeze
        @created_at = Time.now.utc
        @ttl = ttl
        @cache = {}
      end

      # Evaluate a capability through this session's cache.
      # First call runs the full evaluator pipeline and caches the result.
      # Subsequent calls for the same (caller_id, capability_name) return cached.
      def evaluate(evaluator, caller_id:, capability_name:, context: {})
        key = cache_key(caller_id, capability_name)
        return @cache[key] if @cache.key?(key)

        result = evaluator.evaluate(caller_id: caller_id, capability_name: capability_name, context: context)
        @cache[key] = result
        result
      end

      # Check if a result is cached for this caller/capability pair.
      def cached?(caller_id:, capability_name:)
        @cache.key?(cache_key(caller_id, capability_name))
      end

      # Whether this session has exceeded its TTL.
      def expired?
        (Time.now.utc - @created_at) > @ttl
      end

      # Number of cached evaluation results.
      def cache_size
        @cache.size
      end

      private

      def cache_key(caller_id, capability_name)
        [String(caller_id), capability_name.to_sym].freeze
      end
    end
  end
end
