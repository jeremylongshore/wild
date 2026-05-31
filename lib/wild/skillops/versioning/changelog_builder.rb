# frozen_string_literal: true

module Wild
  module Skillops
    module Versioning
      # Builds a human-readable changelog for a skill from its version history.
      class ChangelogBuilder
        def initialize(version_manager:)
          @version_manager = version_manager
        end

        # Returns an Array of changelog lines, newest version first.
        def build(skill_name)
          versions = @version_manager.versions_for(skill_name)
          raise NotFoundError, "Skill '#{skill_name}' not found" if versions.empty?

          versions.reverse.map do |sv|
            entry_line(sv)
          end
        end

        # Returns a formatted multi-line String changelog.
        def build_text(skill_name)
          lines = build(skill_name)
          lines.join("\n")
        end

        private

        def entry_line(version_snapshot)
          change_summary = version_snapshot.changes.empty? ? "No changes recorded" : version_snapshot.changes.join("; ")
          "#{version_snapshot.version} (#{version_snapshot.created_at.strftime("%Y-%m-%d")}): #{change_summary}"
        end
      end
    end
  end
end
