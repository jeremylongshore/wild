# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Guard::PolicyConfig do
  describe ".from_hash" do
    context "with a valid policy hash" do
      subject(:config) { valid_policy_config }

      it "returns a frozen PolicyConfig" do
        expect(config).to be_frozen
      end

      it "sets version to 1" do
        expect(config.version).to eq(1)
      end

      it "exposes all expected categories" do
        expect(config.categories.keys).to contain_exactly("background_jobs", "cache", "feature_flags")
      end

      it "registers all action names" do
        expected = %w[inspect_job retry_job discard_job retry_jobs_by_filter
                      inspect_cache_key invalidate_cache_key
                      read_flag toggle_flag delete_flag]
        expect(config.actions.keys).to match_array(expected)
      end
    end

    context "when version is missing" do
      it "raises ConfigurationError mentioning version" do
        bad = valid_policy_hash.merge("version" => nil)
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /version/)
      end
    end

    context "when operation is invalid" do
      it "raises ConfigurationError mentioning the operation" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["background_jobs"]["actions"].first["operation"] = "destroy"
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /operation.*destroy/)
      end
    end

    context "when a read action has requires_confirmation: true" do
      it "raises ConfigurationError about confirmation" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["cache"]["actions"].first["requires_confirmation"] = true
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /requires_confirmation/)
      end
    end

    context "when a mutate action has requires_confirmation: false" do
      it "raises ConfigurationError about confirmation" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["background_jobs"]["actions"][1]["requires_confirmation"] = false
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /requires_confirmation/)
      end
    end

    context "when rate_limit exceeds the hard ceiling" do
      it "raises ConfigurationError mentioning rate_limit" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["cache"]["actions"].last["rate_limit"] = "200/minute"
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /rate_limit.*ceiling|ceiling.*rate_limit/i)
      end
    end

    context "when blast_radius_cap exceeds the hard ceiling" do
      it "raises ConfigurationError mentioning blast_radius_cap" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["background_jobs"]["actions"][1]["blast_radius_cap"] = 99_999
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /blast_radius_cap/)
      end
    end

    context "when two actions share the same name" do
      it "raises ConfigurationError about duplicate action" do
        bad = valid_policy_hash.tap do |h|
          dupe = h["action_categories"]["background_jobs"]["actions"].first.dup
          h["action_categories"]["cache"]["actions"] << dupe
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /duplicate/)
      end
    end

    context "when an action name has an invalid format" do
      it "raises ConfigurationError about the name format" do
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["cache"]["actions"].first["name"] = "Bad-Name!"
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /name.*Bad-Name!|Bad-Name!.*name/i)
      end
    end

    context "when multiple fields are invalid at once" do
      it "collects all errors into a single raised message" do
        bad = valid_policy_hash.merge("version" => nil).tap do |h|
          h["action_categories"]["background_jobs"]["actions"].first["operation"] = "zap"
        end
        error = nil
        begin
          described_class.from_hash(bad)
        rescue Wild::ConfigurationError => e
          error = e
        end
        expect(error).not_to be_nil
        expect(error.message).to include("version")
      end
    end
  end

  describe "#action" do
    it "returns the action hash for a known action name" do
      config = valid_policy_config
      result = config.action("retry_job")
      expect(result).to be_a(Hash)
      expect(result["operation"]).to eq("mutate")
    end

    it "returns nil for an unknown action name" do
      expect(valid_policy_config.action("nonexistent")).to be_nil
    end
  end

  describe "#actions" do
    it "is frozen" do
      expect(valid_policy_config.actions).to be_frozen
    end
  end
end
