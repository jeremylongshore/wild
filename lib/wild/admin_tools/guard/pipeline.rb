# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      class Pipeline
        def initialize(policy_config:, executors: {})
          @allowlist = ActionAllowlist.new(policy_config)
          @param_validator = ParameterValidator.new
          @blast_enforcer = BlastRadiusEnforcer.new
          @rate_limiter = RateLimiter.new
          @two_phase = TwoPhaseFlow.new
          @policy = policy_config
          @executors = executors
        end

        def call(action_name, params, caller_id, nonce: nil)
          catch(:result) { process(action_name, params, caller_id, nonce) }
        end

        def register_executor(executor)
          executor.action_names.each { |name| @executors[name] = executor }
        end

        private

        # @two_phase has no reader, public or private: TwoPhaseFlow#confirm_and_execute
        # mutates state directly and must only ever be reached through #process
        # below, which enforces the allowlist, param validation, rate limit, and
        # blast-radius checks first (finding f-l10-4, review wave 2026-08-25).
        # See lib/wild/admin_tools.rb's header for the trust boundary this
        # protects: in-process code that reaches @two_phase or an executor
        # directly (bypassing #call) is trusted code running inside this gem's
        # own process, not an external caller: the guard chain's job is to
        # gate the PUBLIC surface (#call / AuditedPipeline#call / ToolHandler),
        # not to defend against code that already runs with this object's
        # privileges. Specs reach it via instance_variable_get(:@two_phase)
        # (see spec/support/wild_admin_tools/safety_helpers.rb#nonce_store),
        # never via a reader (security-review follow-up on f-l10-4, PR #73).
        def process(action_name, params, caller_id, nonce)
          config = check_allowlist!(action_name)
          validated = check_params!(action_name, params, config)
          check_rate_limit!(action_name, caller_id, config)
          executor = find_executor!(action_name)

          route_action(action_name, validated, caller_id, nonce, executor, config)
        end

        # rubocop:disable Metrics/ParameterLists
        def route_action(action_name, params, caller_id, nonce, executor, config)
          if config["operation"] == "read"
            executor.execute(action_name, params)
          elsif nonce
            execute_with_nonce(nonce, action_name, params, caller_id, executor, config)
          else
            preview_mutation(action_name, params, caller_id, executor, config)
          end
        end
        # rubocop:enable Metrics/ParameterLists

        def check_allowlist!(action_name)
          config = @allowlist.action_config(action_name)
          return config if config

          deny!(action_name, "action_not_allowed")
        end

        def check_params!(action_name, params, config)
          result = @param_validator.validate(params, config)
          return result[:params] if result[:valid]

          deny!(action_name, "parameter_validation_failed", errors: result[:errors])
        end

        def check_rate_limit!(action_name, caller_id, config)
          result = @rate_limiter.check(caller_id, action_name, config, build_global_limits)
          return if result[:allowed]

          deny!(action_name, "rate_limited", retry_after_seconds: result[:retry_after_seconds])
        end

        def preview_mutation(action_name, params, caller_id, executor, config)
          check_blast_radius!(action_name, params, executor, config)
          @two_phase.preview_with_nonce(action_name, params, caller_id, executor, config)
        end

        # rubocop:disable Metrics/ParameterLists
        def execute_with_nonce(nonce, action_name, params, caller_id, executor, config)
          check_blast_radius!(action_name, params, executor, config, at_execution: true)
          @two_phase.confirm_and_execute(nonce, action_name, params, caller_id, executor)
        end
        # rubocop:enable Metrics/ParameterLists

        def check_blast_radius!(action_name, params, executor, config, at_execution: false)
          blast = @blast_enforcer.check(config, estimate_count(action_name, params, executor))
          return if blast[:allowed]

          reason = at_execution ? "blast_radius_exceeded_at_execution" : "blast_radius_exceeded"
          deny!(action_name, reason, estimated_count: blast[:estimated_count], cap: blast[:cap])
        end

        def estimate_count(action_name, params, executor)
          preview = executor.preview(action_name, params)
          preview.data[:estimated_affected] || 1
        end

        def find_executor!(action_name)
          @executors.fetch(action_name) { raise ActionNotFoundError, action_name }
        end

        def build_global_limits
          @policy.global_rate_limits
        end

        def deny!(action_name, reason, **extra)
          throw :result, Result.new(
            status: :denied, action: action_name, operation: "unknown",
            metadata: { reason: reason, **extra }
          )
        end
      end
    end
  end
end
