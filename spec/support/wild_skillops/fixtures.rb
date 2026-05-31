# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/ParameterLists

require "time"

module Wild
  module Skillops
    module TestSupport
      module Fixtures
        BASE_TIME = Time.utc(2024, 6, 1, 12, 0, 0)

        module_function

        # ── Skill builders ──────────────────────────────────────────────────────────

        def make_skill(name: "introspect.schema", description: "Introspects Rails schema",
                       repo: "wild-rails-safe-introspection-mcp", version: "1.0.0",
                       tags: %w[introspection schema], category: :introspection,
                       capabilities_required: [], lifecycle_state: :draft,
                       registered_at: nil)
          Wild::Skillops::Models::Skill.new(
            name: name,
            description: description,
            repo: repo,
            version: version,
            tags: tags,
            category: category,
            capabilities_required: capabilities_required,
            lifecycle_state: lifecycle_state,
            registered_at: registered_at || BASE_TIME
          )
        end

        def make_active_skill(name: "admin.reindex", **)
          make_skill(name: name, lifecycle_state: :active, **)
        end

        def make_skill_set(count: 3, prefix: "skill", repo: "wild-test-repo")
          count.times.map do |i|
            make_skill(
              name: "#{prefix}.#{i}",
              description: "Skill number #{i}",
              repo: repo,
              version: "1.0.#{i}",
              tags: ["tag-#{i}", "common"],
              category: :workflow
            )
          end
        end

        # ── Dependency builder ───────────────────────────────────────────────────────

        def make_dependency(skill_name: "introspect.schema", depends_on: "admin.reindex",
                            dependency_type: :required, description: nil)
          Wild::Skillops::Models::Dependency.new(
            skill_name: skill_name,
            depends_on: depends_on,
            dependency_type: dependency_type,
            description: description
          )
        end

        # ── HealthStatus builder ──────────────────────────────────────────────────────

        def make_health(skill_name: "introspect.schema", state: :available,
                        message: nil, last_checked_at: nil)
          Wild::Skillops::Models::HealthStatus.new(
            skill_name: skill_name,
            state: state,
            last_checked_at: last_checked_at || BASE_TIME,
            message: message
          )
        end

        def make_stale_health(skill_name: "introspect.schema")
          threshold = Wild.config.skillops.health_stale_threshold_hours
          stale_time = Time.now.utc - ((threshold + 1) * 3600)
          make_health(skill_name: skill_name, state: :degraded, last_checked_at: stale_time)
        end

        # ── Owner builder ─────────────────────────────────────────────────────────────

        def make_owner(skill_name: "introspect.schema", team: "platform", contact: nil)
          Wild::Skillops::Models::Owner.new(
            skill_name: skill_name,
            team: team,
            contact: contact
          )
        end

        # ── SkillVersion builder ──────────────────────────────────────────────────────

        def make_skill_version(skill_name: "introspect.schema", version: "1.0.0",
                               changes: ["Initial registration"], created_at: nil)
          Wild::Skillops::Models::SkillVersion.new(
            skill_name: skill_name,
            version: version,
            changes: changes,
            created_at: created_at || BASE_TIME
          )
        end

        # ── RegistryEntry builder ─────────────────────────────────────────────────────

        def make_entry(skill: nil, versions: [], health_status: nil, owner: nil, dependencies: [])
          skill ||= make_skill
          Wild::Skillops::Models::RegistryEntry.new(
            skill: skill,
            versions: versions,
            health_status: health_status,
            owner: owner,
            dependencies: dependencies
          )
        end

        # ── Full wired registry ───────────────────────────────────────────────────────

        def build_registry
          Wild::Skillops.build
        end

        def registry_with_skills(count: 3)
          reg = build_registry
          make_skill_set(count: count).each { |s| reg.registrar.register(s) }
          reg
        end

        def populated_registry
          reg = build_registry
          skills = [
            make_skill(name: "introspect.schema", description: "Schema introspection",
                       repo: "wild-rails-safe-introspection-mcp",
                       tags: %w[introspection schema rails], category: :introspection),
            make_skill(name: "admin.reindex", description: "Reindex search index",
                       repo: "wild-admin-tools-mcp",
                       tags: %w[admin search index], category: :admin),
            make_skill(name: "telemetry.flush", description: "Flush telemetry buffer",
                       repo: "wild-session-telemetry",
                       tags: %w[telemetry flush], category: :telemetry),
            make_skill(name: "gap.analyze", description: "Analyze gaps in transcripts",
                       repo: "wild-gap-miner",
                       tags: %w[analysis gap transcript], category: :analysis)
          ]
          skills.each { |s| reg.registrar.register(s) }
          reg
        end
      end
    end
  end
end

# rubocop:enable Metrics/ModuleLength, Metrics/ParameterLists
