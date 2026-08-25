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

  describe "action-level defaults merge (finding f-l10-6)" do
    # hash_with_sparse_action / sparse_action come from PolicyFixtures
    # (spec/support/wild_admin_tools/policy_fixtures.rb): a mutate_destructive
    # action that omits rate_limit, blast_radius_cap, and nonce_ttl_seconds so
    # it must inherit all three from `defaults`.

    it "fills in rate_limit from defaults when the action omits it" do
      config = described_class.from_hash(hash_with_sparse_action)
      expect(config.action("purge_all_jobs")["rate_limit"]).to eq(config.defaults["rate_limit"])
    end

    it "fills in blast_radius_cap from defaults when the action omits it" do
      config = described_class.from_hash(hash_with_sparse_action)
      expect(config.action("purge_all_jobs")["blast_radius_cap"]).to eq(config.defaults["blast_radius_cap"])
    end

    it "fills in nonce_ttl_seconds from defaults when the action omits it" do
      config = described_class.from_hash(hash_with_sparse_action)
      expect(config.action("purge_all_jobs")["nonce_ttl_seconds"]).to eq(config.defaults["nonce_ttl_seconds"])
    end

    it "lets an explicit per-action value win over defaults" do
      hash = valid_policy_hash.tap do |h|
        h["action_categories"]["background_jobs"]["actions"] << {
          "name" => "purge_all_jobs",
          "operation" => "mutate_destructive",
          "requires_confirmation" => true,
          "rate_limit" => "5/minute"
        }
      end
      config = described_class.from_hash(hash)
      expect(config.action("purge_all_jobs")["rate_limit"]).to eq("5/minute")
    end
  end

  describe "defaults ceiling validation (security-review follow-up on f-l10-6, PR #73)" do
    # Before this fix, ActionValidator validated the RAW action_hash, not the
    # merged-over-defaults hash actually stored and later handed to
    # RateLimiter/BlastRadiusEnforcer. An over-ceiling `defaults` section
    # loaded clean and silently authorized every action that omitted its own
    # cap. These specs fail on main (no ConfigurationError raised) and pass
    # on this branch.
    context "when defaults.blast_radius_cap exceeds the hard ceiling" do
      it "raises ConfigurationError mentioning defaults.blast_radius_cap" do
        bad = valid_policy_hash.tap do |h|
          h["defaults"]["blast_radius_cap"] = 1_000_000
          h["hard_ceilings"]["max_blast_radius"] = 5
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /defaults\.blast_radius_cap/)
      end
    end

    context "when defaults.rate_limit exceeds the hard ceiling" do
      it "raises ConfigurationError mentioning defaults.rate_limit" do
        bad = valid_policy_hash.tap do |h|
          h["defaults"]["rate_limit"] = "200/minute"
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /defaults\.rate_limit/)
      end
    end

    context "when defaults.nonce_ttl_seconds is outside the hard ceiling bounds" do
      it "raises ConfigurationError mentioning defaults.nonce_ttl_seconds" do
        bad = valid_policy_hash.tap do |h|
          h["defaults"]["nonce_ttl_seconds"] = 999
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /defaults\.nonce_ttl_seconds/)
      end
    end

    context "when a valid defaults section is inherited by an action" do
      it "still loads cleanly and the action is checked at the inherited value" do
        # sparse_action (PolicyFixtures) omits blast_radius_cap, so it inherits
        # defaults.blast_radius_cap (1), within the fixture's max_blast_radius
        # (1000) ceiling.
        config = sparse_policy_config
        expect(config.action("purge_all_jobs")["blast_radius_cap"]).to eq(config.defaults["blast_radius_cap"])
      end
    end

    context "when defaults has an unknown key" do
      it "raises ConfigurationError mentioning the unknown key" do
        bad = valid_policy_hash.tap do |h|
          h["defaults"]["parameters"] = { "required" => [] }
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /defaults has unknown key.*parameters/)
      end
    end

    context "when defaults.requires_confirmation is present but not inherited by any action" do
      it "does not fill in an action's missing requires_confirmation from defaults" do
        # requires_confirmation is a required key of `defaults` (structural
        # completeness) but is deliberately NOT in INHERITABLE_ACTION_KEYS: an
        # action must always declare it explicitly. Omitting it entirely is a
        # missing-required-field error, not a fall-through to defaults.
        bad = valid_policy_hash.tap do |h|
          h["action_categories"]["background_jobs"]["actions"] << {
            "name" => "purge_all_jobs",
            "operation" => "mutate_destructive"
            # requires_confirmation intentionally omitted entirely.
          }
        end
        expect { described_class.from_hash(bad) }
          .to raise_error(Wild::ConfigurationError, /missing required field 'requires_confirmation'/)
      end
    end
  end

  describe "explicit-nil inheritable keys (blank-scalar YAML idiom, f-l10-6 follow-up)" do
    it "treats an explicit nil rate_limit as absent and inherits the default" do
      hash = valid_policy_hash.tap do |h|
        h["action_categories"]["background_jobs"]["actions"] << {
          "name" => "purge_all_jobs",
          "operation" => "mutate_destructive",
          "requires_confirmation" => true,
          "rate_limit" => nil # the `rate_limit: ~` YAML idiom
        }
      end
      config = described_class.from_hash(hash)
      expect(config.action("purge_all_jobs")["rate_limit"]).to eq(config.defaults["rate_limit"])
    end

    it "treats an explicit nil blast_radius_cap as absent and inherits the default" do
      hash = valid_policy_hash.tap do |h|
        h["action_categories"]["background_jobs"]["actions"] << {
          "name" => "purge_all_jobs",
          "operation" => "mutate_destructive",
          "requires_confirmation" => true,
          "blast_radius_cap" => nil
        }
      end
      config = described_class.from_hash(hash)
      expect(config.action("purge_all_jobs")["blast_radius_cap"]).to eq(config.defaults["blast_radius_cap"])
    end
  end

  describe "categories/actions parity (finding f-l10-6 follow-up, PR #73)" do
    it "exposes the same merged action hash from #categories as from #action" do
      config = sparse_policy_config

      from_categories = config.categories["background_jobs"]["actions"].find { |a| a["name"] == "purge_all_jobs" }

      expect(from_categories).to eq(config.action("purge_all_jobs"))
      expect(from_categories["blast_radius_cap"]).to eq(config.defaults["blast_radius_cap"])
    end

    it "keeps non-action category fields (e.g. description) intact" do
      config = valid_policy_config
      expect(config.categories["background_jobs"]["description"]).to eq("Background job management")
    end
  end
end
