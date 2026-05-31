# frozen_string_literal: true

RSpec.describe Wild::Skillops::Models::HealthStatus do
  describe "#initialize" do
    it "creates with valid attributes" do
      hs = make_health
      expect(hs.skill_name).to eq("introspect.schema")
      expect(hs.state).to eq(:available)
      expect(hs.message).to be_nil
    end

    it "accepts all allowed health states" do
      Wild.config.skillops.allowed_health_states.each do |state|
        expect { make_health(state: state) }.not_to raise_error
      end
    end

    it "defaults last_checked_at to now" do
      hs = described_class.new(skill_name: "foo", state: :available)
      expect(hs.last_checked_at).to be_a(Time)
    end

    it "raises ValidationError for blank skill_name" do
      expect do
        described_class.new(skill_name: "", state: :available)
      end.to raise_error(Wild::Skillops::ValidationError, /skill_name/)
    end

    it "raises ValidationError for invalid state" do
      expect do
        described_class.new(skill_name: "foo", state: :exploded)
      end.to raise_error(Wild::Skillops::ValidationError, /state/)
    end

    it "raises ValidationError for non-String message" do
      expect do
        described_class.new(skill_name: "foo", state: :available, message: 123)
      end.to raise_error(Wild::Skillops::ValidationError, /message/)
    end
  end

  describe "#stale?" do
    it "returns false for a recently checked status" do
      hs = make_health(last_checked_at: Time.now.utc)
      expect(hs.stale?).to be false
    end

    it "returns true when last_checked_at exceeds the stale threshold" do
      hs = make_stale_health
      expect(hs.stale?).to be true
    end

    it "uses the configured stale threshold" do
      Wild.configure { |c| c.skillops.health_stale_threshold_hours = 1 }
      old_time = Time.now.utc - 7200
      hs = make_health(last_checked_at: old_time)
      expect(hs.stale?).to be true
    end
  end

  describe "#to_h" do
    it "includes stale key" do
      hs = make_health
      h = hs.to_h
      expect(h).to include(:stale)
    end
  end
end
