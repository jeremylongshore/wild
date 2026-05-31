# frozen_string_literal: true

RSpec.describe Wild::Skillops::Governance::OwnershipResolver do
  let(:registry) { populated_registry }
  let(:resolver) { registry.ownership_resolver }

  describe "#assign" do
    it "assigns an owner to a skill" do
      owner = resolver.assign("introspect.schema", team: "platform")
      expect(owner.team).to eq("platform")
      expect(owner.skill_name).to eq("introspect.schema")
    end

    it "assigns an owner with contact info" do
      owner = resolver.assign("admin.reindex", team: "ops", contact: "ops@example.com")
      expect(owner.contact).to eq("ops@example.com")
    end

    it "replaces an existing owner" do
      resolver.assign("introspect.schema", team: "old-team")
      resolver.assign("introspect.schema", team: "new-team")
      expect(resolver.owner_for("introspect.schema").team).to eq("new-team")
    end

    it "raises NotFoundError for unknown skill" do
      expect do
        resolver.assign("nope", team: "team")
      end.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#owner_for" do
    it "returns nil when no owner assigned" do
      expect(resolver.owner_for("introspect.schema")).to be_nil
    end

    it "returns the assigned owner" do
      resolver.assign("admin.reindex", team: "eng")
      expect(resolver.owner_for("admin.reindex").team).to eq("eng")
    end
  end

  describe "#unowned_entries" do
    it "returns all entries when none have owners" do
      expect(resolver.unowned_entries.size).to eq(4)
    end

    it "excludes owned entries" do
      resolver.assign("introspect.schema", team: "platform")
      expect(resolver.unowned_entries.size).to eq(3)
    end
  end

  describe "#entries_for_team" do
    it "returns all entries owned by a team" do
      resolver.assign("introspect.schema", team: "platform")
      resolver.assign("admin.reindex", team: "platform")
      resolver.assign("telemetry.flush", team: "data")
      platform = resolver.entries_for_team("platform")
      expect(platform.map(&:name)).to match_array(%w[introspect.schema admin.reindex])
    end

    it "returns empty array for unknown team" do
      expect(resolver.entries_for_team("ghost-team")).to eq([])
    end
  end
end
