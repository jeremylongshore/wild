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
          @sweep_thread = nil
        end

        def store(entry)
          @mutex.synchronize do
            @entries[entry.nonce] = entry
            start_sweep_thread_locked
          end
        end

        def fetch(nonce)
          @mutex.synchronize { @entries[nonce] }
        end

        def consume!(nonce)
          @mutex.synchronize { unsafe_consume!(nonce) }
        end

        # Atomic compare-and-set: checks "not already consumed" and marks the
        # entry consumed inside a single mutex acquisition, closing the
        # fetch/check/consume! race that let concurrent confirms of the same
        # nonce all pass (finding f-l10-1). Returns false, never raises, when
        # the nonce is missing or already consumed (the caller cannot tell
        # those two apart from the return value alone, which is fine because
        # NonceManager only needs "did I win the race", not "why not").
        def consume_if_unconsumed!(nonce)
          @mutex.synchronize do
            entry = @entries[nonce]
            next false if entry.nil? || entry.consumed

            unsafe_consume!(nonce)
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
            @sweep_cv.broadcast
            @sweep_thread
          end
          thread&.join(1)
          @sweep_thread = nil
        end

        private

        # Rewrites the entry as consumed and returns true. Callers MUST hold
        # @mutex already (this method does not lock), so it can be reused by
        # both #consume! (unconditional) and #consume_if_unconsumed! (guarded)
        # without acquiring the mutex twice or re-checking existence.
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
          return if @running

          @running = true
          @sweep_thread = Thread.new do
            Thread.current.abort_on_exception = false
            @mutex.synchronize do
              while @running
                @sweep_cv.wait(@mutex, 10)
                sweep_expired_locked if @running
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
