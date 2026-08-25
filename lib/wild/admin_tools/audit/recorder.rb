# frozen_string_literal: true

module Wild
  module AdminTools
    module Audit
      class Recorder
        RecordContext = Struct.new(
          :action_name, :caller_id, :sanitized_params,
          :nonce, :session_context
        )

        def initialize(store:, sanitizer: ParameterSanitizer.new)
          @store = store
          @sanitizer = sanitizer
        end

        attr_reader :store

        def record(action_name:, params:, caller_id:, nonce: nil, session_context: nil)
          ctx = RecordContext.new(
            action_name: action_name, caller_id: caller_id,
            sanitized_params: @sanitizer.sanitize(params),
            nonce: nonce, session_context: session_context
          )
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = yield
          @store.append(build_record(ctx, result, elapsed_ms(start_time)))
          result
        rescue StandardError => e
          @store.append(build_error_record(ctx, e, elapsed_ms(start_time)))
          raise
        end

        private

        # rubocop:disable Metrics/AbcSize
        def build_record(ctx, result, duration_ms)
          Record.new(
            caller_id: ctx.caller_id,
            action: ctx.action_name,
            category: extract_category(ctx.action_name),
            parameters: ctx.sanitized_params,
            phase: map_phase(result),
            confirmation_nonce: ctx.nonce,
            gate_result: extract_gate_result(ctx.session_context),
            outcome: result.status.to_s,
            # Prefer the internal reason (nonce not_found/expired/already_used/
            # mismatch) when present so the audit trail keeps full fidelity even
            # though the client-facing :reason is deliberately opaque
            # (Security Decision 8, see guard/nonce_manager.rb). Other denial
            # paths never set an audit-only key, so this falls back to :reason.
            # `Result::AUDIT_ONLY_METADATA_KEYS` is the same set
            # Server::ResponseFormatter strips before the client ever sees it
            # (security-review follow-up on f-l10-6, PR #73).
            denial_reason: result.denied? ? (result.metadata[Result::AUDIT_ONLY_METADATA_KEYS.first] || result.metadata[:reason]) : nil, # rubocop:disable Layout/LineLength
            before_snapshot: result.before_snapshot,
            after_snapshot: result.after_snapshot,
            duration_ms: duration_ms
          )
        end
        # rubocop:enable Metrics/AbcSize

        def build_error_record(ctx, error, duration_ms)
          Record.new(
            caller_id: ctx.caller_id,
            action: ctx.action_name,
            category: extract_category(ctx.action_name),
            parameters: ctx.sanitized_params,
            phase: "error",
            confirmation_nonce: ctx.nonce,
            gate_result: extract_gate_result(ctx.session_context),
            outcome: "error",
            duration_ms: duration_ms,
            error_message: "#{error.class}: #{error.message}"
          )
        end

        def map_phase(result)
          case result.status
          when :success then "execute"
          when :preview then "preview"
          when :denied then "denied"
          when :error then "error"
          else "unknown"
          end
        end

        def extract_category(action_name)
          case action_name.to_s
          when /^(inspect_job|list_failed|list_queue|retry_job|discard_job)/
            "background_jobs"
          when /^(inspect_cache|list_cache|invalidate_cache)/
            "cache"
          when /^(read_flag|list_flag|toggle_flag|enable_flag|disable_flag|delete_flag)/
            "feature_flags"
          else
            "unknown"
          end
        end

        def extract_gate_result(session_context)
          return "not_checked" if session_context.nil?

          session_context.respond_to?(:gate_result) ? session_context.gate_result.to_s : "not_checked"
        end

        def elapsed_ms(start_time)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        end
      end
    end
  end
end
