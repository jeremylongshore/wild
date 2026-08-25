# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/ModuleLength

module Wild
  module AdminTools
    module TestSupport
      module SafetyHelpers
        # All mutation actions with their tool class and valid preview params
        MUTATION_ACTIONS = [
          ["ManageBackgroundJobs", "retry_job", { job_id: "job-1" }],
          ["ManageBackgroundJobs", "discard_job", { job_id: "job-1" }],
          ["ManageBackgroundJobs", "retry_jobs_by_filter", { filter: { "queue_name" => "default" } }],
          ["ManageBackgroundJobs", "discard_jobs_by_filter", { filter: { "queue_name" => "default" } }],
          ["ManageCache", "invalidate_cache_key", { cache_key: "cache:1" }],
          ["ManageCache", "invalidate_cache_pattern", { pattern: "cache:" }],
          ["ManageFeatureFlags", "toggle_flag", { flag_name: "test_flag", enabled: true }],
          ["ManageFeatureFlags", "enable_flag_for_actor",
           { flag_name: "test_flag", actor_type: "User", actor_id: "user-1" }],
          ["ManageFeatureFlags", "disable_flag_for_actor",
           { flag_name: "test_flag", actor_type: "User", actor_id: "user-1" }],
          ["ManageFeatureFlags", "enable_flag_percentage", { flag_name: "test_flag", percentage: 50 }],
          ["ManageFeatureFlags", "delete_flag", { flag_name: "test_flag" }]
        ].freeze

        def resolve_tool(name)
          Wild::AdminTools::Server::Tools.const_get(name)
        end

        # `target` defaults to the example group's `pipeline` let, but can be
        # any Guard::Pipeline or object that wraps one (AuditedPipeline,
        # AuthenticatedPipeline, ...) so every spec reaches the nonce store
        # through this one helper instead of re-inlining the ivar chain
        # (pipeline.rb has no #two_phase reader at all, it is dead in lib,
        # only specs ever needed it: security-review follow-up on f-l10-6,
        # PR #73).
        def nonce_store(target = pipeline)
          two_phase_flow(target).nonce_manager.store
        end

        def expire_nonce!(nonce)
          entry = nonce_store.fetch(nonce)
          nonce_store.remove(nonce)
          nonce_store.store(
            Guard::NonceEntry.new(
              nonce: entry.nonce, binding_hash: entry.binding_hash,
              action_name: entry.action_name, caller_id: entry.caller_id,
              expires_at: Time.now.utc - 1
            )
          )
        end

        def all_write_calls
          job_adapter.write_methods_called +
            cache_adapter.write_methods_called +
            flag_adapter.write_methods_called
        end

        def full_policy_config
          Guard::PolicyConfig.from_hash(full_policy_hash)
        end

        # Complete 19-action policy covering all executor actions.
        def full_policy_hash
          {
            "version" => 1,
            "defaults" => {
              "rate_limit" => "30/minute", "blast_radius_cap" => 1,
              "requires_confirmation" => true, "nonce_ttl_seconds" => 30
            },
            "hard_ceilings" => {
              "max_rate_limit" => "60/minute", "max_blast_radius" => 1000,
              "max_nonce_ttl_seconds" => 120, "min_nonce_ttl_seconds" => 10
            },
            "global_rate_limits" => {
              "all_mutations" => "120/minute", "all_reads" => "600/minute"
            },
            "action_categories" => {
              "background_jobs" => { "description" => "Jobs", "actions" => job_actions },
              "cache" => { "description" => "Cache", "actions" => cache_actions },
              "feature_flags" => { "description" => "Flags", "actions" => flag_actions }
            }
          }
        end

        private

        # Reaches Guard::Pipeline's @two_phase ivar directly (no reader
        # exists in lib; see pipeline.rb), unwrapping AuditedPipeline's
        # @pipeline or AuthenticatedPipeline's @audited_pipeline as needed.
        def two_phase_flow(candidate)
          return candidate.instance_variable_get(:@two_phase) if candidate.is_a?(Wild::AdminTools::Guard::Pipeline)

          inner = candidate.instance_variable_get(:@pipeline) || candidate.instance_variable_get(:@audited_pipeline)
          raise "cannot locate Guard::Pipeline from #{candidate.class}" if inner.nil?

          two_phase_flow(inner)
        end

        def job_id_spec
          { "name" => "job_id", "type" => "string",
            "validation" => { "format" => "^[a-zA-Z0-9_-]{1,255}$" } }
        end

        def flag_name_spec
          { "name" => "flag_name", "type" => "string",
            "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,128}$" } }
        end

        def cache_key_spec
          { "name" => "cache_key", "type" => "string",
            "validation" => { "max_length" => 512 } }
        end

        def filter_spec
          { "name" => "filter", "type" => "object",
            "properties" => { "queue_name" => { "type" => "string" } },
            "min_properties" => 1 }
        end

        def max_count_spec
          { "name" => "max_count", "type" => "integer",
            "validation" => { "min" => 1, "max" => 100 }, "default" => 10 }
        end

        def actor_type_spec
          { "name" => "actor_type", "type" => "string",
            "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,128}$" } }
        end

        def actor_id_spec
          { "name" => "actor_id", "type" => "string",
            "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,255}$" } }
        end

        def read_action(name, params)
          { "name" => name, "operation" => "read", "requires_confirmation" => false,
            "blast_radius_cap" => 1, "rate_limit" => "60/minute", "parameters" => params }
        end

        def mutate_action(name, params, rate_limit: "10/minute", blast_radius_cap: 1)
          { "name" => name, "operation" => "mutate", "requires_confirmation" => true,
            "blast_radius_cap" => blast_radius_cap, "rate_limit" => rate_limit,
            "parameters" => params }
        end

        def destructive_action(name, params, rate_limit: "3/minute", blast_radius_cap: 1)
          { "name" => name, "operation" => "mutate_destructive", "requires_confirmation" => true,
            "blast_radius_cap" => blast_radius_cap, "rate_limit" => rate_limit,
            "nonce_ttl_seconds" => 15, "parameters" => params }
        end

        def req(specs)
          { "required" => specs.is_a?(Array) ? specs : [specs], "optional" => [] }
        end

        def req_opt(required, optional)
          { "required" => required.is_a?(Array) ? required : [required],
            "optional" => optional.is_a?(Array) ? optional : [optional] }
        end

        def empty_params
          { "required" => [], "optional" => [] }
        end

        def job_actions
          [
            read_action("inspect_job", req(job_id_spec)),
            read_action("list_failed_jobs", req_opt([], [
                                                      { "name" => "queue_name", "type" => "string" },
                                                      { "name" => "error_class", "type" => "string" },
                                                      { "name" => "limit", "type" => "integer",
                                                        "validation" => { "min" => 1, "max" => 1000 },
                                                        "default" => 50 }
                                                    ])),
            read_action("list_queues", empty_params),
            mutate_action("retry_job", req(job_id_spec)),
            destructive_action("discard_job", req(job_id_spec)),
            mutate_action("retry_jobs_by_filter", req_opt(filter_spec, max_count_spec),
                          rate_limit: "3/minute", blast_radius_cap: 100),
            destructive_action("discard_jobs_by_filter", req_opt(filter_spec, max_count_spec),
                               blast_radius_cap: 100)
          ]
        end

        def cache_actions
          [
            read_action("inspect_cache_key", req(cache_key_spec)),
            read_action("inspect_cache_stats", empty_params),
            read_action("list_cache_keys", req_opt([], [
                                                     { "name" => "prefix", "type" => "string" },
                                                     { "name" => "limit", "type" => "integer",
                                                       "validation" => { "min" => 1, "max" => 1000 },
                                                       "default" => 50 }
                                                   ])),
            mutate_action("invalidate_cache_key", req(cache_key_spec), rate_limit: "30/minute"),
            destructive_action("invalidate_cache_pattern", req(
                                                             { "name" => "pattern", "type" => "string",
                                                               "validation" => { "max_length" => 512 } }
                                                           ), blast_radius_cap: 500, rate_limit: "5/minute")
          ]
        end

        def flag_actions
          actor_params = req([flag_name_spec, actor_type_spec, actor_id_spec])
          [
            read_action("read_flag", req(flag_name_spec)),
            read_action("list_flags", req_opt([], [
                                                { "name" => "filter", "type" => "string" },
                                                { "name" => "enabled_only", "type" => "boolean" },
                                                { "name" => "limit", "type" => "integer",
                                                  "validation" => { "min" => 1, "max" => 1000 },
                                                  "default" => 100 }
                                              ])),
            mutate_action("toggle_flag", req([flag_name_spec,
                                              { "name" => "enabled", "type" => "boolean" }])),
            mutate_action("enable_flag_for_actor", actor_params),
            mutate_action("disable_flag_for_actor", actor_params),
            mutate_action("enable_flag_percentage", req([flag_name_spec,
                                                         { "name" => "percentage", "type" => "integer",
                                                           "validation" => { "min" => 0,
                                                                             "max" => 100 } }])),
            destructive_action("delete_flag", req(flag_name_spec))
          ]
        end
      end
    end
  end
end

# rubocop:enable Metrics/AbcSize, Metrics/ModuleLength
