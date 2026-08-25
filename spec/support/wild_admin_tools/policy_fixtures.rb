# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/ModuleLength

module Wild
  module AdminTools
    module TestSupport
      module PolicyFixtures
        def valid_policy_hash
          {
            "version" => 1,
            "defaults" => {
              "rate_limit" => "30/minute",
              "blast_radius_cap" => 1,
              "requires_confirmation" => true,
              "nonce_ttl_seconds" => 30
            },
            "hard_ceilings" => {
              "max_rate_limit" => "60/minute",
              "max_blast_radius" => 1000,
              "max_nonce_ttl_seconds" => 120,
              "min_nonce_ttl_seconds" => 10
            },
            "global_rate_limits" => {
              "all_mutations" => "120/minute",
              "all_reads" => "600/minute"
            },
            "action_categories" => {
              "background_jobs" => {
                "description" => "Background job management",
                "actions" => [
                  {
                    "name" => "inspect_job",
                    "operation" => "read",
                    "requires_confirmation" => false,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "60/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "job_id", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_-]{1,255}$" } }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "retry_job",
                    "operation" => "mutate",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "10/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "job_id", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_-]{1,255}$" } }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "discard_job",
                    "operation" => "mutate_destructive",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "10/minute",
                    "nonce_ttl_seconds" => 15,
                    "parameters" => {
                      "required" => [
                        { "name" => "job_id", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_-]{1,255}$" } }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "retry_jobs_by_filter",
                    "operation" => "mutate",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 100,
                    "rate_limit" => "3/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "filter", "type" => "object",
                          "properties" => { "queue_name" => { "type" => "string" } },
                          "min_properties" => 1 }
                      ],
                      "optional" => [
                        { "name" => "max_count", "type" => "integer",
                          "validation" => { "min" => 1, "max" => 100 }, "default" => 10 }
                      ]
                    }
                  }
                ]
              },
              "cache" => {
                "description" => "Cache management",
                "actions" => [
                  {
                    "name" => "inspect_cache_key",
                    "operation" => "read",
                    "requires_confirmation" => false,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "60/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "cache_key", "type" => "string",
                          "validation" => { "max_length" => 512 } }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "invalidate_cache_key",
                    "operation" => "mutate",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "30/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "cache_key", "type" => "string",
                          "validation" => { "max_length" => 512 } }
                      ],
                      "optional" => []
                    }
                  }
                ]
              },
              "feature_flags" => {
                "description" => "Feature flag management",
                "actions" => [
                  {
                    "name" => "read_flag",
                    "operation" => "read",
                    "requires_confirmation" => false,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "60/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "flag_name", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,128}$" } }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "toggle_flag",
                    "operation" => "mutate",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "10/minute",
                    "parameters" => {
                      "required" => [
                        { "name" => "flag_name", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,128}$" } },
                        { "name" => "enabled", "type" => "boolean" }
                      ],
                      "optional" => []
                    }
                  },
                  {
                    "name" => "delete_flag",
                    "operation" => "mutate_destructive",
                    "requires_confirmation" => true,
                    "blast_radius_cap" => 1,
                    "rate_limit" => "3/minute",
                    "nonce_ttl_seconds" => 15,
                    "parameters" => {
                      "required" => [
                        { "name" => "flag_name", "type" => "string",
                          "validation" => { "format" => "^[a-zA-Z0-9_.-]{1,128}$" } }
                      ],
                      "optional" => []
                    }
                  }
                ]
              }
            }
          }
        end

        def valid_policy_config
          Wild::AdminTools::Guard::PolicyConfig.from_hash(valid_policy_hash)
        end

        # A mutate_destructive action that omits rate_limit, blast_radius_cap,
        # and nonce_ttl_seconds so it must inherit all three from `defaults`
        # (PolicyConfig::INHERITABLE_ACTION_KEYS). Shared by every spec that
        # exercises the defaults-inheritance path (finding f-l10-6) instead of
        # each redefining the same literal (security-review follow-up on
        # f-l10-6, PR #73).
        def sparse_action
          {
            "name" => "purge_all_jobs",
            "operation" => "mutate_destructive",
            "requires_confirmation" => true
            # rate_limit / blast_radius_cap / nonce_ttl_seconds intentionally
            # absent: the action must inherit them from `defaults`.
          }
        end

        def hash_with_sparse_action
          valid_policy_hash.tap do |h|
            h["action_categories"]["background_jobs"]["actions"] << sparse_action
          end
        end

        def sparse_policy_config
          Wild::AdminTools::Guard::PolicyConfig.from_hash(hash_with_sparse_action)
        end
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength, Metrics/ModuleLength
