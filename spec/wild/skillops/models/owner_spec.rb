# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::Owner do
  describe "#initialize" do
    it "creates with valid attributes" do
      owner = make_owner
      expect(owner.skill_name).to eq("introspect.schema")
      expect(owner.team).to eq("platform")
      expect(owner.contact).to be_nil
    end

    it "accepts an optional contact" do
      owner = make_owner(contact: "team@example.com")
      expect(owner.contact).to eq("team@example.com")
    end

    it "raises ValidationError for blank skill_name" do
      expect { make_owner(skill_name: "") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises ValidationError for blank team" do
      expect { make_owner(team: "") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises ValidationError for non-String team" do
      expect { make_owner(team: 42) }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises ValidationError for non-String contact" do
      expect { make_owner(contact: 99) }.to raise_error(Wild::Skillops::ValidationError)
    end
  end

  describe "#to_h" do
    it "includes skill_name, team, and contact" do
      owner = make_owner(contact: "eng@example.com")
      h = owner.to_h
      expect(h).to include(skill_name: "introspect.schema", team: "platform", contact: "eng@example.com")
    end
  end
end
