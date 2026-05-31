# frozen_string_literal: true

module Wild
  module Skillops
    module Export
      # Exports the registry as a human-readable Markdown catalog.
      class MarkdownExporter
        def initialize(store:)
          @store = store
        end

        def export
          lines = catalog_header
          @store.all.sort_by(&:name).each { |entry| lines.concat(render_entry(entry)) }
          lines.join("\n")
        end

        def export_skill(skill_name)
          entry = @store.fetch(skill_name)
          render_entry(entry).join("\n")
        end

        private

        def catalog_header
          [
            "# Skill Registry Catalog",
            "",
            "_Generated: #{Time.now.utc.strftime("%Y-%m-%d %H:%M UTC")}_",
            "",
            "**Total skills:** #{@store.size}",
            ""
          ]
        end

        def render_entry(entry)
          lines = skill_core_lines(entry.skill)
          lines.concat(owner_lines(entry.owner))
          lines.concat(health_lines(entry.health_status))
          lines.concat(dependency_lines(entry.dependencies))
          lines << "---"
          lines << ""
          lines
        end

        def skill_core_lines(skill)
          [
            "## #{skill.name}",
            "",
            "**Description:** #{skill.description}",
            "**Repo:** #{skill.repo}",
            "**Version:** #{skill.version}",
            "**Category:** #{skill.category}",
            "**Lifecycle:** #{skill.lifecycle_state}",
            "**Tags:** #{skill.tags.empty? ? "_none_" : skill.tags.join(", ")}",
            ""
          ]
        end

        def owner_lines(owner)
          return [] unless owner

          contact_part = owner.contact ? " (#{owner.contact})" : ""
          ["**Owner:** #{owner.team}#{contact_part}", ""]
        end

        def health_lines(health_status)
          return [] unless health_status

          lines = build_health_lines(health_status)
          lines << ""
          lines
        end

        def build_health_lines(status)
          stale_note = status.stale? ? " _(stale)_" : ""
          lines = [
            "**Health:** #{status.state}#{stale_note}",
            "**Last checked:** #{status.last_checked_at.strftime("%Y-%m-%d %H:%M UTC")}"
          ]
          lines << "_#{status.message}_" if status.message
          lines
        end

        def dependency_lines(dependencies)
          return [] if dependencies.empty?

          lines = ["**Dependencies:**"]
          dependencies.each { |dep| lines << "- #{dep.depends_on} (#{dep.dependency_type})" }
          lines << ""
          lines
        end
      end
    end
  end
end
