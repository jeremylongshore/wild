# frozen_string_literal: true

module Wild
  module Introspection
    module Audit
      module Recorder
        def self.record(tool_name:, model_name:, parameters:, request_context:, &)
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = execute_with_rescue(&)
        ensure
          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
          emit_audit_record(
            tool_name, model_name, parameters,
            result || { status: :error, reason: :internal_error },
            duration_ms, request_context
          )
        end

        def self.execute_with_rescue
          yield
        rescue StandardError => e
          { status: :error, reason: :internal_error, error_message: e.message }
        end
        private_class_method :execute_with_rescue

        def self.build_audit_attrs(tool_name, model_name, parameters, result, duration_ms)
          {
            tool_name: tool_name, model_name: model_name,
            parameters: ParameterSanitizer.sanitize(tool_name, model_name, parameters),
            guard_result: map_guard_result(result), outcome: map_outcome(result),
            duration_ms: duration_ms, rows_returned: count_rows(result),
            truncated: result[:truncated] == true,
            error_message: result[:error_message]
          }
        end
        private_class_method :build_audit_attrs

        def self.emit_audit_record(tool_name, model_name, parameters, result, duration_ms, ctx) # rubocop:disable Metrics/ParameterLists
          attrs = build_audit_attrs(tool_name, model_name, parameters, result, duration_ms)
          attrs[:caller_id] = ctx.caller_id
          attrs[:caller_type] = ctx.caller_type
          AuditLogger.log(AuditRecord.new(**attrs))
        end
        private_class_method :emit_audit_record

        def self.map_guard_result(result)
          case result[:status]
          when :ok, :not_found
            "allowed"
          when :denied
            "denied_#{result[:reason]}"
          when :error
            result[:reason] == :query_timeout ? "denied_query_timeout" : "error_#{result[:reason]}"
          else
            "unknown"
          end
        end
        private_class_method :map_guard_result

        def self.map_outcome(result)
          case result[:status]
          when :ok, :not_found
            "success"
          when :denied
            "denied"
          when :error
            result[:reason] == :query_timeout ? "timeout" : "error"
          else
            "error"
          end
        end
        private_class_method :map_outcome

        def self.count_rows(result)
          return 0 unless result[:status] == :ok

          if result.key?(:record)
            result[:record] ? 1 : 0
          elsif result.key?(:records)
            result[:records].size
          else
            0
          end
        end
        private_class_method :count_rows
      end
    end
  end
end
