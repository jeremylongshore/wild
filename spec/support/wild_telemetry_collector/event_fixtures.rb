# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module TestSupport
        module EventFixtures
          def valid_action_completed_event
            {
              event_type: "action.completed",
              timestamp: "2026-03-19T14:30:00.000Z",
              caller_id: "service-account-ops",
              action: "retry_job",
              outcome: "success",
              duration_ms: 42.5,
              metadata: { category: "background_jobs", operation: "mutate" }
            }
          end

          def valid_gate_evaluated_event
            {
              event_type: "gate.evaluated",
              timestamp: "2026-03-19T14:30:01.000Z",
              caller_id: "service-account-ops",
              action: "retry_job",
              outcome: "success",
              metadata: { gate_result: "allowed", capability_checked: "admin_tools.retry_job" }
            }
          end

          def valid_rate_limit_checked_event
            {
              event_type: "rate_limit.checked",
              timestamp: "2026-03-19T14:30:02.000Z",
              caller_id: "service-account-ops",
              action: "retry_job",
              outcome: "success",
              metadata: { rate_result: "allowed", current_count: 7, limit: 10, window_seconds: 60 }
            }
          end

          def build_envelope(overrides = {})
            attrs = valid_action_completed_event.merge(overrides)
            Wild::Telemetry::Collector::Schema::EventEnvelope.new(**attrs)
          end
        end
      end
    end
  end
end
