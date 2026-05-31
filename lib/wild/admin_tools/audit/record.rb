# frozen_string_literal: true

require "securerandom"

module Wild
  module AdminTools
    module Audit
      Record = Data.define(
        :id,
        :timestamp,
        :caller_id,
        :action,
        :category,
        :parameters,
        :phase,
        :confirmation_nonce,
        :gate_result,
        :outcome,
        :denial_reason,
        :before_snapshot,
        :after_snapshot,
        :duration_ms,
        :error_message,
        :server_version
      ) do
        # rubocop:disable Metrics/ParameterLists
        def initialize(
          caller_id:,
          action:,
          outcome:,
          id: SecureRandom.uuid,
          timestamp: Time.now.utc.iso8601(3),
          category: "unknown",
          parameters: {},
          phase: "execute",
          confirmation_nonce: nil,
          gate_result: "not_checked",
          denial_reason: nil,
          before_snapshot: nil,
          after_snapshot: nil,
          duration_ms: nil,
          error_message: nil,
          server_version: Wild::VERSION
        )
          super
        end
        # rubocop:enable Metrics/ParameterLists

        def success?
          outcome == "success"
        end

        def denied?
          outcome == "denied"
        end

        def error?
          outcome == "error"
        end

        def preview?
          outcome == "preview"
        end

        def to_h
          {
            id: id, timestamp: timestamp, caller_id: caller_id,
            action: action, category: category, parameters: parameters,
            phase: phase, confirmation_nonce: confirmation_nonce,
            gate_result: gate_result, outcome: outcome,
            denial_reason: denial_reason,
            before_snapshot: before_snapshot, after_snapshot: after_snapshot,
            duration_ms: duration_ms, error_message: error_message,
            server_version: server_version
          }
        end
      end
    end
  end
end
