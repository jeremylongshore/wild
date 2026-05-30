# frozen_string_literal: true

module Wild
  module CapabilityGate
    class Session
      # In-memory session store for creating, looking up, and cleaning
      # up sessions. Sessions are keyed by their ID.
      #
      # This is a simple v1 implementation: a hash in the process.
      # No database. No Redis. No cross-process sharing.
      # See 004-AT-ADEC-architecture-decisions.md (Decision 3).
      class Store
        def initialize(default_ttl: Session::DEFAULT_TTL)
          @sessions = {}
          @default_ttl = default_ttl
        end

        # Create a new session and register it in the store.
        def create(id: nil, ttl: @default_ttl)
          session = Session.new(id: id, ttl: ttl)
          @sessions[session.id] = session
          session
        end

        # Look up a session by ID. Returns nil if not found or expired.
        def find(id)
          session = @sessions[id]
          return nil if session.nil?

          if session.expired?
            @sessions.delete(id)
            return nil
          end

          session
        end

        # Remove all expired sessions from the store.
        def cleanup
          expired_ids = @sessions.select { |_, s| s.expired? }.keys
          expired_ids.each { |id| @sessions.delete(id) }
          expired_ids.size
        end

        # Number of sessions currently in the store (including expired).
        delegate :size, to: :@sessions

        # Remove all sessions.
        delegate :clear, to: :@sessions
      end
    end
  end
end
