# frozen_string_literal: true

module Wild
  module Hooks
    module Audit
      # Monotonic clock wrapper for measuring `audit_emit_ms` (the F2 audit-
      # liveness metric per `000-docs/003-AT-ARCH-architecture.md § Audit trail`)
      # and other audit-record timing fields.
      #
      # Both `wild-rails-safe-introspection-mcp` and `wild-admin-tools-mcp`
      # inlined the same `Process.clock_gettime(Process::CLOCK_MONOTONIC)`
      # snippet at every emission site. Pulling it up makes it discoverable,
      # testable, and consistent across audit emitters in any namespace —
      # including the F2 emitter Wild::CapabilityGate will use when
      # wild-rvv.4.1 lands.
      #
      # Example
      #
      #   start = Wild::Hooks::Audit::Timer.now
      #   do_work
      #   elapsed = Wild::Hooks::Audit::Timer.elapsed_ms(start)
      #
      # Closes the structural-duplication portion of wild-rvv.6.2.
      module Timer
        # The current monotonic clock value (seconds, Float). Use as a
        # baseline; the absolute value is not meaningful — only differences
        # between two `now` calls are.
        #
        # @return [Float]
        def self.now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Elapsed milliseconds since `start`, rounded to integer.
        # F2 audit-liveness specs use this to detect emitters that silently
        # fail (real emit takes >0 ms; mocked emit returns 0 → fails).
        #
        # @param start [Float] a prior `Timer.now` value
        # @return [Integer]
        def self.elapsed_ms(start)
          ((now - start) * 1000).round
        end
      end
    end
  end
end
