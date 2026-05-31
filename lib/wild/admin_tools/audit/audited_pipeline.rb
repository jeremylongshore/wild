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

        delegate :two_phase, to: :@pipeline
      end
    end
  end
end
