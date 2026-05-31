# frozen_string_literal: true

require "tmpdir"
require "yaml"

module Wild
  module Analyzers
    module Permission
      module TestSupport
        module Fixtures
          # ---------------------------------------------------------------------------
          # Capability builders
          # ---------------------------------------------------------------------------

          def low_cap(name: "admin.jobs.view", prereqs: [], tags: ["admin"])
            Wild::Analyzers::Permission::Models::Capability.new(
              name: name,
              description: "View background job status",
              risk_level: "low",
              prerequisites: prereqs,
              tags: tags
            )
          end

          def medium_cap(name: "admin.jobs.retry", prereqs: ["admin.jobs.view"], tags: ["admin"])
            Wild::Analyzers::Permission::Models::Capability.new(
              name: name,
              description: "Retry failed background jobs",
              risk_level: "medium",
              prerequisites: prereqs,
              tags: tags
            )
          end

          def high_cap(name: "admin.users.delete", prereqs: [], tags: %w[admin users])
            Wild::Analyzers::Permission::Models::Capability.new(
              name: name,
              description: "Delete user accounts",
              risk_level: "high",
              prerequisites: prereqs,
              tags: tags
            )
          end

          def critical_cap(name: "admin.system.shutdown", prereqs: [], tags: %w[admin system])
            Wild::Analyzers::Permission::Models::Capability.new(
              name: name,
              description: "Shut down the system",
              risk_level: "critical",
              prerequisites: prereqs,
              tags: tags
            )
          end

          def standard_capabilities
            [low_cap, medium_cap, high_cap, critical_cap]
          end

          # ---------------------------------------------------------------------------
          # Grant builders
          # ---------------------------------------------------------------------------

          def ops_grant(caps: ["admin.jobs.*"], expires: nil)
            Wild::Analyzers::Permission::Models::Grant.new(
              caller_id: "ops-team",
              capabilities: caps,
              context: { "environment" => "production" },
              expires_at: expires
            )
          end

          def intern_grant(caps: ["admin.jobs.view"], expires: "2026-06-01")
            Wild::Analyzers::Permission::Models::Grant.new(
              caller_id: "dev-intern",
              capabilities: caps,
              context: { "environment" => "staging" },
              expires_at: expires
            )
          end

          def standard_grants
            [ops_grant, intern_grant]
          end

          # ---------------------------------------------------------------------------
          # YAML file helpers
          # ---------------------------------------------------------------------------

          def write_capabilities_yaml(entries, dir)
            path = File.join(dir, "capabilities.yml")
            File.write(path, YAML.dump("capabilities" => entries))
            path
          end

          def write_grants_yaml(entries, dir)
            path = File.join(dir, "grants.yml")
            File.write(path, YAML.dump("grants" => entries))
            path
          end

          def default_capabilities_yaml_entries
            [
              { "name" => "admin.jobs.view", "description" => "View jobs", "risk_level" => "low",
                "prerequisites" => [], "tags" => ["admin"] },
              { "name" => "admin.jobs.retry", "description" => "Retry jobs", "risk_level" => "medium",
                "prerequisites" => ["admin.jobs.view"], "tags" => ["admin"] },
              { "name" => "admin.users.delete", "description" => "Delete users", "risk_level" => "high",
                "prerequisites" => [], "tags" => ["admin"] },
              { "name" => "admin.system.shutdown", "description" => "Shutdown system", "risk_level" => "critical",
                "prerequisites" => [], "tags" => ["admin"] }
            ]
          end

          def default_grants_yaml_entries
            [
              { "caller_id" => "ops-team", "capabilities" => ["admin.jobs.*"],
                "context" => { "environment" => "production" }, "expires_at" => nil },
              { "caller_id" => "dev-intern", "capabilities" => ["admin.jobs.view"],
                "context" => { "environment" => "staging" }, "expires_at" => "2026-06-01" }
            ]
          end
        end
      end
    end
  end
end
