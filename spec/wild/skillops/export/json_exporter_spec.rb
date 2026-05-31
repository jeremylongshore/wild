# frozen_string_literal: true

require "json"

RSpec.describe Wild::Skillops::Export::JsonExporter do
  let(:registry) { populated_registry }
  let(:exporter) { registry.json_exporter }

  describe "#export" do
    it "returns a Hash with exported_at, skill_count, and skills" do
      data = exporter.export
      expect(data).to include(:exported_at, :skill_count, :skills)
    end

    it "reports correct skill count" do
      expect(exporter.export[:skill_count]).to eq(4)
    end

    it "includes all skill hashes" do
      expect(exporter.export[:skills].size).to eq(4)
    end
  end

  describe "#export_json" do
    it "returns valid compact JSON string" do
      json = exporter.export_json
      expect { JSON.parse(json) }.not_to raise_error
    end

    it "returns pretty-printed JSON when pretty: true" do
      json = exporter.export_json(pretty: true)
      expect(json).to include("\n")
    end
  end

  describe "#export_skill" do
    it "returns a JSON string for a single skill" do
      json = exporter.export_skill("introspect.schema")
      parsed = JSON.parse(json)
      expect(parsed).to include("skill")
    end

    it "raises NotFoundError for unknown skill" do
      expect do
        exporter.export_skill("nope")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end
  end
end
