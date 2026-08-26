# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      # Immutable value object representing a stored nonce entry.
      NonceEntry = Data.define(:nonce, :binding_hash, :action_name, :caller_id, :expires_at, :consumed) do
        def initialize(nonce:, binding_hash:, action_name:, caller_id:, expires_at:, consumed: false)
          super
        end
      end

      # Thread-safe in-memory nonce storage with background TTL sweep.
      #
      # Uses a Mutex to protect the internal hash and a daemon sweep thread
      # (started lazily on first #store, one per NonceStore instance) that
      # evicts expired entries every 10 seconds.
      class NonceStore
        def initialize
          @entries = {}
          @mutex = Mutex.new
          @sweep_cv = ConditionVariable.new
          @running = false
          @stopping = false
          @restart_requested = false
          @sweep_thread = nil
        end

        def store(entry)
          @mutex.synchronize do
            @entries[entry.nonce] = entry
            @restart_requested = true if @stopping
            start_sweep_thread_locked
          end
        end

        def fetch(nonce)
          @mutex.synchronize { @entries[nonce] }
        end

        # rubocop:disable Naming/PredicateMethod -- retained compatibility
        # API; it is a mutator whose boolean reports whether it consumed.
        def consume!(nonce)
          consume_if_unconsumed!(nonce) == :consumed
        end
        # rubocop:enable Naming/PredicateMethod

        # Atomically validate and consume a nonce. The optional block returns
        # nil when the entry binding is acceptable, or a failure reason when
        # it is not. Expiry, consumed state, binding validation, and the write
        # all happen under one mutex acquisition, so a nonce cannot become
        # expired or consumed between validation and consumption.
        #
        # Returns :consumed, :not_found, :expired, :already_used, or the
        # failure reason supplied by the block.
        def consume_if_unconsumed!(nonce)
          @mutex.synchronize do
            entry = @entries[nonce]
            next :not_found if entry.nil?

            if entry.expires_at < Time.now.utc
              @entries.delete(nonce)
              next :expired
            end

            next :already_used if entry.consumed

            failure_reason = yield(entry) if block_given?
            next failure_reason if failure_reason

            unsafe_consume!(nonce)
            :consumed
          end
        end

        def remove(nonce)
          @mutex.synchronize { @entries.delete(nonce) }
        end

        def size
          @mutex.synchronize { @entries.size }
        end

        def clear!
          @mutex.synchronize { @entries.clear }
        end

        # Signals the sweep thread to stop and wakes it immediately (via the
        # condition variable) instead of waiting up to 10s for its next
        # `sleep` to elapse, then joins it with a bounded timeout so a caller
        # can never hang here.
        def stop_sweep!
          thread = @mutex.synchronize do
            @running = false
            @stopping = true
            @sweep_cv.broadcast
            @sweep_thread
          end
          thread&.join(1)
        end

        private

        # Rewrites the entry as consumed and returns true. Callers MUST hold
        # @mutex already. It is deliberately private so public callers cannot
        # bypass the single-use compare-and-set in #consume_if_unconsumed!.
        #
        # rubocop:disable Naming/PredicateMethod -- this is a mutator (bang
        # suffix, rewrites @entries), not a query; "did it exist to mutate"
        # is a legitimate boolean return on a `!` method, not a `?` method.
        def unsafe_consume!(nonce)
          entry = @entries[nonce]
          return false unless entry

          @entries[nonce] = NonceEntry.new(
            nonce: entry.nonce,
            binding_hash: entry.binding_hash,
            action_name: entry.action_name,
            caller_id: entry.caller_id,
            expires_at: entry.expires_at,
            consumed: true
          )
          true
        end
        # rubocop:enable Naming/PredicateMethod

        # Callers MUST hold @mutex already. Spawning the thread under the same
        # lock that guards @running closes the race where two threads could
        # both observe `@running == false` and each spawn their own sweeper
        # (finding f-l10-9).
        def start_sweep_thread_locked
          return if @running || @stopping

          @running = true
          @sweep_thread = Thread.new do
            Thread.current.abort_on_exception = false
            @mutex.synchronize do
              while @running
                @sweep_cv.wait(@mutex, 10)
                sweep_expired_locked if @running
              end
            ensure
              if Thread.current.equal?(@sweep_thread)
                @sweep_thread = nil
                @stopping = false
                restart = @restart_requested
                @restart_requested = false
                start_sweep_thread_locked if restart
              end
            end
          end
        end

        # Callers MUST hold @mutex already.
        def sweep_expired_locked
          now = Time.now.utc
          @entries.delete_if { |_k, entry| entry.expires_at < now }
        end
      end
    end
  end
end
