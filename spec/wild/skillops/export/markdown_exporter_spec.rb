# frozen_string_literal: true

RSpec.describe Wild::Skillops::Export::MarkdownExporter do
  let(:registry) { populated_registry }
  let(:exporter) { registry.markdown_exporter }

  describe "#export" do
    it "returns a String starting with the catalog header" do
      md = exporter.export
      expect(md).to start_with("# Skill Registry Catalog")
    end

    it "includes all skill names as headings" do
      md = exporter.export
      expect(md).to include("## introspect.schema")
      expect(md).to include("## admin.reindex")
    end

    it "includes skill metadata" do
      md = exporter.export
      expect(md).to include("wild-rails-safe-introspection-mcp")
      expect(md).to include("introspection")
    end

    it "includes owner info when present" do
      registry.ownership_resolver.assign("introspect.schema", team: "platform")
      md = exporter.export
      expect(md).to include("platform")
    end

    it "includes health status when present" do
      registry.health_tracker.record("admin.reindex", state: :available)
      md = exporter.export
      expect(md).to include("available")
    end

    it "includes stale note when health is stale" do
      stale_time = Time.now.utc - (25 * 3600)
      registry.health_tracker.record("telemetry.flush", state: :degraded, checked_at: stale_time)
      md = exporter.export
      expect(md).to include("stale")
    end
  end

  describe "#export_skill" do
    it "returns markdown for a single skill" do
      md = exporter.export_skill("introspect.schema")
      expect(md).to include("## introspect.schema")
    end

    it "raises NotFoundError for unknown skill" do
      expect do
        exporter.export_skill("nope")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end
  end
end
