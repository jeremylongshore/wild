# frozen_string_literal: true

RSpec.describe Wild::Hooks::Lifecycle::VersionTracker do
  subject(:tracker) { described_class.new }

  describe "#record" do
    it "records a version entry and returns it" do
      entry = tracker.record("my_hook", "2.0.0")
      expect(entry.hook_name).to eq("my_hook")
      expect(entry.version).to eq("2.0.0")
      expect(entry.changed_at).to be_a(Time)
    end

    it "accumulates multiple entries for the same hook" do
      tracker.record("my_hook", "1.0.0")
      tracker.record("my_hook", "2.0.0")
      expect(tracker.history_for("my_hook").size).to eq(2)
    end
  end

  describe "#history_for" do
    it "returns empty array for unknown hook" do
      expect(tracker.history_for("unknown")).to eq([])
    end

    it "returns entries in order" do
      tracker.record("my_hook", "1.0.0")
      tracker.record("my_hook", "1.1.0")
      versions = tracker.history_for("my_hook").map(&:version)
      expect(versions).to eq(["1.0.0", "1.1.0"])
    end
  end

  describe "#current_version" do
    it "returns nil for unknown hook" do
      expect(tracker.current_version("unknown")).to be_nil
    end

    it "returns the most recent version" do
      tracker.record("my_hook", "1.0.0")
      tracker.record("my_hook", "2.0.0")
      expect(tracker.current_version("my_hook")).to eq("2.0.0")
    end
  end

  describe "#all_history" do
    it "returns a hash keyed by hook_name" do
      tracker.record("hook_a", "1.0.0")
      tracker.record("hook_b", "1.0.0")
      expect(tracker.all_history.keys).to contain_exactly("hook_a", "hook_b")
    end
  end

  describe "#clear!" do
    it "removes all history" do
      tracker.record("my_hook", "1.0.0")
      tracker.clear!
      expect(tracker.history_for("my_hook")).to eq([])
    end
  end
end
