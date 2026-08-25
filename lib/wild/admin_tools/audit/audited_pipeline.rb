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

        # No delegation for :two_phase, and Guard::Pipeline never exposes a
        # reader for it either way (see pipeline.rb). This removes an unused
        # PUBLIC handle, not a security boundary against in-process code: any
        # object already holding a reference to @pipeline (or to an executor)
        # inside this gem's own process is trusted code, not an external
        # caller, and could always reach TwoPhaseFlow/executor methods
        # directly via instance_variable_get regardless of what this class
        # delegates. What #call/#delegate control is the PUBLIC surface every
        # untrusted caller (an MCP client via ToolHandler) is limited to:
        # #call is the only entry point that runs the allowlist, param
        # validation, rate limit, blast-radius checks, and this class's audit
        # wrapper before a mutation reaches an executor (finding f-l10-4,
        # review wave 2026-08-25; wording corrected, security-review
        # follow-up on f-l10-4, PR #73).
      end
    end
  end
end
