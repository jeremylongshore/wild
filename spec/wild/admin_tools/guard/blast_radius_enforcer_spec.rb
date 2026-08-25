# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::AdminTools::Guard::BlastRadiusEnforcer do
  subject(:enforcer) { described_class.new }

  let(:policy) { valid_policy_config }

  delegate :action, to: :policy

  describe "#check" do
    context "when estimated_count is within the cap" do
      it "returns allowed: true" do
        result = enforcer.check(action("retry_job"), 1)
        expect(result[:allowed]).to be(true)
      end

      it "includes estimated_count and cap in the result" do
        result = enforcer.check(action("retry_jobs_by_filter"), 50)
        expect(result[:estimated_count]).to eq(50)
        expect(result[:cap]).to eq(100)
      end
    end

    context "when estimated_count exceeds the cap" do
      it "returns allowed: false" do
        result = enforcer.check(action("retry_job"), 5)
        expect(result[:allowed]).to be(false)
      end

      it "includes a reason of blast_radius_exceeded" do
        result = enforcer.check(action("retry_job"), 5)
        expect(result[:reason]).to eq("blast_radius_exceeded")
      end
    end

    context "when estimated_count is exactly at the cap" do
      it "returns allowed: true" do
        result = enforcer.check(action("retry_jobs_by_filter"), 100)
        expect(result[:allowed]).to be(true)
      end
    end

    context "for read operations" do
      it "returns allowed: true even when count exceeds the cap" do
        result = enforcer.check(action("inspect_job"), 9_999)
        expect(result[:allowed]).to be(true)
      end
    end

    context "when an action inherits blast_radius_cap from defaults (finding f-l10-6 follow-up)" do
      it "is still enforced at the inherited default value" do
        # sparse_action (PolicyFixtures) omits blast_radius_cap, so it
        # inherits defaults.blast_radius_cap (1).
        config = sparse_policy_config

        result = enforcer.check(config.action("purge_all_jobs"), 2)

        expect(result[:allowed]).to be(false)
        expect(result[:cap]).to eq(config.defaults["blast_radius_cap"])
      end
    end

    context "when blast_radius_cap is missing or not an Integer (defense in depth)" do
      it "returns allowed: false with an explicit reason instead of raising" do
        bad_config = { "operation" => "mutate", "blast_radius_cap" => nil }

        expect { enforcer.check(bad_config, 1) }.not_to raise_error
        result = enforcer.check(bad_config, 1)

        expect(result[:allowed]).to be(false)
        expect(result[:reason]).to eq("missing_or_invalid_blast_radius_cap")
      end
    end
  end
end

# rubocop:enable RSpec/ContextWording
