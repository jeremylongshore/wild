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
      # that evicts expired entries every 10 seconds.
      class NonceStore
        def initialize
          @entries = {}
          @mutex = Mutex.new
          @running = false
          @sweep_thread = nil
        end

        def store(entry)
          @mutex.synchronize { @entries[entry.nonce] = entry }
          start_sweep_thread unless @running
        end

        def fetch(nonce)
          @mutex.synchronize { @entries[nonce] }
        end

        def consume!(nonce)
          @mutex.synchronize do
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

        def stop_sweep!
          @running = false
          @sweep_thread&.join(1)
          @sweep_thread = nil
        end

        private

        def start_sweep_thread
          return if @running

          @running = true
          @sweep_thread = Thread.new do
            Thread.current.abort_on_exception = false
            while @running
              sleep 10
              sweep_expired
            end
          end
          @sweep_thread
        end

        def sweep_expired
          now = Time.now.utc
          @mutex.synchronize { @entries.delete_if { |_k, entry| entry.expires_at < now } }
        end
      end
    end
  end
end
