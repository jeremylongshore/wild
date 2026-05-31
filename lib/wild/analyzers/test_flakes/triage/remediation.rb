# frozen_string_literal: true

module Wild
  module Analyzers
    module TestFlakes
      module Triage
        class Remediation
          SUGGESTIONS = {
            timing_dependent: [
              "Add explicit waits or retry logic for time-sensitive operations",
              "Increase timeout thresholds for slow CI environments",
              "Mock time-dependent code with deterministic values",
              "Extract timing logic into configurable delays"
            ],
            order_dependent: [
              "Add database cleanup between tests (use DatabaseCleaner or equivalent)",
              "Ensure each test sets up its own state independently",
              "Run suspect test in isolation to confirm order dependency",
              "Add explicit teardown for any global/class-level state"
            ],
            shared_state: [
              "Add before/after hooks to reset shared state",
              "Use let/let! instead of instance variables in RSpec",
              "Check for class-level memoization or caching",
              "Audit any constants or class variables modified during tests"
            ],
            external_dependency: [
              "Mock or stub external HTTP/API calls",
              "Use VCR or WebMock to record and replay network interactions",
              "Add retry logic with exponential backoff for flaky dependencies",
              "Add integration test tag and exclude from standard runs"
            ],
            random_seed: [
              "Pin the random seed for deterministic test runs during debugging",
              "Remove or isolate tests that depend on random data ordering",
              "Use factory patterns that produce deterministic data",
              "Check for shuffle! or sample calls on shared arrays"
            ],
            resource_contention: [
              "Run tests with lower parallelism to reduce resource pressure",
              "Check for port conflicts in parallel test runs",
              "Add file locking for tests that write to shared files",
              "Isolate resource-intensive tests into a separate suite"
            ],
            timezone_locale: [
              'Set explicit timezone in test setup (e.g., Time.zone = "UTC")',
              "Use travel_to or freeze_time helpers for time-sensitive assertions",
              "Avoid locale-dependent string formatting in assertions",
              'Set ENV["TZ"] = "UTC" in test configuration'
            ],
            unknown: [
              "Run test in isolation to determine if it fails alone",
              "Add verbose logging to capture state at failure time",
              "Review recent changes to this test file",
              "Check for any recently introduced global state changes"
            ]
          }.freeze

          def suggestions_for(root_causes)
            return SUGGESTIONS[:unknown] if root_causes.blank?

            primary = root_causes.max_by(&:confidence)
            SUGGESTIONS.fetch(primary.category, SUGGESTIONS[:unknown])
          end

          def all_suggestions_for(root_causes)
            return SUGGESTIONS[:unknown] if root_causes.blank?

            root_causes
              .sort_by { |rc| -rc.confidence }
              .flat_map { |rc| SUGGESTIONS.fetch(rc.category, []) }
              .uniq
              .first(6)
          end
        end
      end
    end
  end
end
