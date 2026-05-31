# frozen_string_literal: true

require "json"

module Wild
  module Skillops
    module Export
      # Exports the registry as a JSON document.
      class JsonExporter
        def initialize(store:)
          @store = store
        end

        def export
          {
            exported_at: Time.now.utc.iso8601,
            skill_count: @store.size,
            skills: @store.all.map(&:to_h)
          }
        end

        def export_json(pretty: false)
          data = export
          pretty ? JSON.pretty_generate(data) : JSON.generate(data)
        end

        def export_skill(skill_name)
          entry = @store.fetch(skill_name)
          JSON.pretty_generate(entry.to_h)
        end
      end
    end
  end
end
