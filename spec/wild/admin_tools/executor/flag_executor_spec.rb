# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Executor::FlagExecutor do
  let(:adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }
  let(:executor) { described_class.new }

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = Wild::AdminTools::TestSupport::TestJobAdapter.new
      c.cache_adapter = Wild::AdminTools::TestSupport::TestCacheAdapter.new
      c.flag_adapter = adapter
    end
    adapter.seed_flag("new_dashboard", enabled: true, percentage: nil, actors: [])
    adapter.seed_flag("beta_feature", enabled: false, percentage: 25, actors: ["User;42"])
    adapter.seed_flag("old_feature", enabled: true)
  end

  describe "read actions" do
    it_behaves_like "a read action", "read_flag", { flag_name: "new_dashboard" }
    it_behaves_like "a read action", "list_flags", {}

    describe "read_flag preview data" do
      it "includes flag details" do
        result = executor.preview("read_flag", { flag_name: "new_dashboard" })
        expect(result.data[:flag]).to include(name: "new_dashboard", enabled: true)
      end

      it "returns nil for nonexistent flag" do
        result = executor.preview("read_flag", { flag_name: "nonexistent" })
        expect(result.data[:flag]).to be_nil
      end
    end

    describe "list_flags" do
      it "returns all flags" do
        result = executor.preview("list_flags", {})
        expect(result.data[:flags].size).to eq(3)
      end

      it "filters by enabled_only" do
        result = executor.preview("list_flags", { enabled_only: true })
        expect(result.data[:flags].size).to eq(2)
      end
    end
  end

  describe "mutating actions" do
    it_behaves_like "a mutating action", "toggle_flag", "mutate",
                    { flag_name: "new_dashboard", enabled: false }
    it_behaves_like "a mutating action", "enable_flag_for_actor", "mutate",
                    { flag_name: "new_dashboard", actor_type: "User", actor_id: "99" }
    it_behaves_like "a mutating action", "disable_flag_for_actor", "mutate",
                    { flag_name: "beta_feature", actor_type: "User", actor_id: "42" }
    it_behaves_like "a mutating action", "enable_flag_percentage", "mutate",
                    { flag_name: "beta_feature", percentage: 50 }
    it_behaves_like "a mutating action", "delete_flag", "mutate_destructive",
                    { flag_name: "old_feature" }

    describe "toggle_flag" do
      it "toggles the flag state" do
        executor.execute("toggle_flag", { flag_name: "new_dashboard", enabled: false })
        flag = adapter.read_flag("new_dashboard")
        expect(flag[:enabled]).to be false
      end
    end

    describe "enable_flag_for_actor" do
      it "adds actor to flag" do
        executor.execute("enable_flag_for_actor",
                         { flag_name: "new_dashboard", actor_type: "User", actor_id: "99" })
        flag = adapter.read_flag("new_dashboard")
        expect(flag[:actors]).to include("User;99")
      end
    end

    describe "disable_flag_for_actor" do
      it "removes actor from flag" do
        executor.execute("disable_flag_for_actor",
                         { flag_name: "beta_feature", actor_type: "User", actor_id: "42" })
        flag = adapter.read_flag("beta_feature")
        expect(flag[:actors]).not_to include("User;42")
      end
    end

    describe "enable_flag_percentage" do
      it "sets the percentage" do
        executor.execute("enable_flag_percentage", { flag_name: "beta_feature", percentage: 50 })
        flag = adapter.read_flag("beta_feature")
        expect(flag[:percentage]).to eq(50)
      end
    end

    describe "delete_flag" do
      it "removes the flag" do
        executor.execute("delete_flag", { flag_name: "old_feature" })
        expect(adapter.read_flag("old_feature")).to be_nil
      end
    end
  end

  describe "state capture" do
    it "captures before/after snapshots on toggle" do
      result = executor.execute("toggle_flag", { flag_name: "new_dashboard", enabled: false })
      expect(result.before_snapshot).to include(flag_name: "new_dashboard", enabled: true)
      expect(result.after_snapshot).to include(flag_name: "new_dashboard", enabled: false)
    end
  end
end
