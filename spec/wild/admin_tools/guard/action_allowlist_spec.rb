# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Guard::ActionAllowlist do
  subject(:allowlist) { described_class.new(valid_policy_config) }

  describe "#allowed?" do
    context "with a known action name" do
      it "returns true" do
        expect(allowlist.allowed?("retry_job")).to be(true)
      end
    end

    context "with an unknown action name" do
      it "returns false" do
        expect(allowlist.allowed?("drop_database")).to be(false)
      end
    end
  end

  describe "#action_config" do
    context "with a known action name" do
      it "returns a Hash with the action configuration" do
        config = allowlist.action_config("inspect_job")
        expect(config).to be_a(Hash)
        expect(config["operation"]).to eq("read")
      end
    end

    context "with an unknown action name" do
      it "returns nil" do
        expect(allowlist.action_config("does_not_exist")).to be_nil
      end
    end
  end

  describe "#all_action_names" do
    it "returns all registered action names" do
      names = allowlist.all_action_names
      expect(names).to include("inspect_job", "retry_job", "discard_job",
                               "toggle_flag", "delete_flag", "invalidate_cache_key")
    end

    it "returns only strings" do
      expect(allowlist.all_action_names).to all(be_a(String))
    end
  end

  describe "#operation_for" do
    it "returns the operation string for a known action" do
      expect(allowlist.operation_for("discard_job")).to eq("mutate_destructive")
    end

    it "returns nil for an unknown action" do
      expect(allowlist.operation_for("ghost_action")).to be_nil
    end
  end

  describe "#check!" do
    context "with an unknown action name" do
      it "raises ActionNotFoundError" do
        expect { allowlist.check!("not_real") }
          .to raise_error(Wild::AdminTools::ActionNotFoundError, /not_real/)
      end
    end

    context "with a known action name" do
      it "does not raise" do
        expect { allowlist.check!("toggle_flag") }.not_to raise_error
      end
    end
  end
end
