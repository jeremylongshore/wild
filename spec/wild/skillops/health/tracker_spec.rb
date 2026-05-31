# frozen_string_literal: true

RSpec.describe Wild::Skillops::Health::Tracker do
  let(:registry) { build_registry }
  let(:tracker)  { registry.health_tracker }

  before do
    registry.registrar.register(make_skill(name: "tracked.skill"))
  end

  describe "#record" do
    it "records health status for a skill" do
      hs = tracker.record("tracked.skill", state: :available)
      expect(hs.state).to eq(:available)
      expect(hs.skill_name).to eq("tracked.skill")
    end

    it "accepts an optional message" do
      hs = tracker.record("tracked.skill", state: :degraded, message: "slow responses")
      expect(hs.message).to eq("slow responses")
    end

    it "accepts a custom checked_at time" do
      t = Time.now.utc - 3600
      hs = tracker.record("tracked.skill", state: :available, checked_at: t)
      expect(hs.last_checked_at).to eq(t)
    end

    it "overwrites previous health status" do
      tracker.record("tracked.skill", state: :available)
      tracker.record("tracked.skill", state: :unavailable)
      expect(tracker.status_for("tracked.skill").state).to eq(:unavailable)
    end

    it "raises NotFoundError for unknown skill" do
      expect do
        tracker.record("nope", state: :available)
      end.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#status_for" do
    it "returns nil when no health status recorded" do
      reg = build_registry
      reg.registrar.register(make_skill(name: "untracked"))
      expect(reg.health_tracker.status_for("untracked")).to be_nil
    end

    it "returns the HealthStatus after recording" do
      tracker.record("tracked.skill", state: :available)
      expect(tracker.status_for("tracked.skill")).to be_a(Wild::Skillops::Models::HealthStatus)
    end
  end

  describe "#stale?" do
    it "returns false when no health status recorded" do
      expect(tracker.stale?("tracked.skill")).to be false
    end

    it "returns false for a fresh health check" do
      tracker.record("tracked.skill", state: :available, checked_at: Time.now.utc)
      expect(tracker.stale?("tracked.skill")).to be false
    end

    it "returns true when health check is old" do
      stale_time = Time.now.utc - (25 * 3600)
      tracker.record("tracked.skill", state: :available, checked_at: stale_time)
      expect(tracker.stale?("tracked.skill")).to be true
    end
  end
end
