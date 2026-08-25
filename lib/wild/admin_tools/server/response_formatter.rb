# frozen_string_literal: true

require "json"

module Wild
  module AdminTools
    module Server
      module ResponseFormatter
        def self.format(result)
          body = result_to_hash(result)
          is_error = result.denied? || result.error?

          MCP::Tool::Response.new(
            [{ type: "text", text: JSON.generate(body) }],
            error: is_error,
            structured_content: body
          )
        end

        def self.format_error(action_name, error)
          body = {
            status: "error",
            action: action_name,
            message: error.message
          }

          MCP::Tool::Response.new(
            [{ type: "text", text: JSON.generate(body) }],
            error: true,
            structured_content: body
          )
        end

        def self.result_to_hash(result)
          case result.status
          when :success then success_hash(result)
          when :preview then preview_hash(result)
          when :denied  then denied_hash(result)
          when :error   then error_hash(result)
          end
        end

        private_class_method :result_to_hash

        def self.success_hash(result)
          {
            status: "success",
            action: result.action,
            operation: result.operation,
            data: result.data,
            before_snapshot: result.before_snapshot,
            after_snapshot: result.after_snapshot,
            metadata: strip_audit_only(result.metadata)
          }.compact
        end

        def self.preview_hash(result)
          {
            status: "preview",
            action: result.action,
            operation: result.operation,
            data: result.data,
            metadata: strip_audit_only(result.metadata)
          }.compact
        end

        def self.denied_hash(result)
          # Every denial's metadata (rate_limited's retry_after_seconds,
          # blast_radius's estimated_count/cap, parameter validation's errors)
          # is intentionally client-facing and stays in the splat; only
          # Result::AUDIT_ONLY_METADATA_KEYS is stripped.
          {
            status: "denied",
            action: result.action,
            **strip_audit_only(result.metadata)
          }
        end

        def self.error_hash(result)
          {
            status: "error",
            action: result.action,
            message: result.metadata[:message] || "An error occurred"
          }
        end

        # Applied to every status's metadata, not just :denied, so an
        # audit-only key (currently just :internal_reason, set today by
        # TwoPhaseFlow's nonce denial path) can never reach the client
        # regardless of which result status it ends up attached to
        # (security-review follow-up on f-l10-6, PR #73).
        def self.strip_audit_only(metadata)
          metadata.except(*Result::AUDIT_ONLY_METADATA_KEYS)
        end

        private_class_method :success_hash, :preview_hash, :denied_hash, :error_hash, :strip_audit_only
      end
    end
  end
end
