# frozen_string_literal: true

module Wild
  module AdminTools
    module Audit
      class AuditedPipeline
        def initialize(pipeline:, recorder:)
          @pipeline = pipeline
          @recorder = recorder
        end

        attr_reader :recorder

        def call(action_name, params, caller_id, nonce: nil, session_context: nil)
          @recorder.record(
            action_name: action_name,
            params: params,
            caller_id: caller_id,
            nonce: nonce,
            session_context: session_context
          ) do
            @pipeline.call(action_name, params, caller_id, nonce: nonce)
          end
        end

        delegate :register_executor, to: :@pipeline

        # No delegation for :two_phase. Delegating it would hand any holder of
        # this object a way to mint a nonce and call TwoPhaseFlow#confirm_and_execute
        # directly, bypassing Pipeline#call's allowlist, rate limit, and blast-radius
        # checks and this class's own audit wrapper (finding f-l10-4, review wave
        # 2026-08-25). Nothing in lib needs it: #call is the only sanctioned entry
        # point for both preview and confirm.
      end
    end
  end
end
