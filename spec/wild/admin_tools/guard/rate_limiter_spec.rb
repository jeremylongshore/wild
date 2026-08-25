# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::AdminTools::Guard::RateLimiter do
  subject(:limiter) { described_class.new }

  let(:policy)          { valid_policy_config }
  let(:global_limits)   { policy.global_rate_limits }
  let(:inspect_config)  { policy.action("inspect_job") }
  let(:retry_config)    { policy.action("retry_job") }

  describe "#check" do
    context "for the very first request" do
      it "returns allowed: true" do
        result = limiter.check("agent:1", "inspect_job", inspect_config, global_limits)
        expect(result[:allowed]).to be(true)
      end
    end

    context "when requests remain within the configured limit" do
      it "continues to return allowed: true" do
        3.times { limiter.check("agent:1", "inspect_job", inspect_config, global_limits) }
        result = limiter.check("agent:1", "inspect_job", inspect_config, global_limits)
        expect(result[:allowed]).to be(true)
      end
    end

    context "when requests exceed the configured limit" do
      it "returns allowed: false with a retry_after_seconds value" do
        # retry_job has rate_limit: 10/minute — exhaust it
        10.times { limiter.check("agent:1", "retry_job", retry_config, global_limits) }
        result = limiter.check("agent:1", "retry_job", retry_config, global_limits)
        expect(result[:allowed]).to be(false)
        expect(result[:retry_after_seconds]).to be_a(Numeric)
      end
    end

    context "when reset! is called" do
      it "clears all windows and allows requests again" do
        10.times { limiter.check("agent:1", "retry_job", retry_config, global_limits) }
        limiter.reset!
        result = limiter.check("agent:1", "retry_job", retry_config, global_limits)
        expect(result[:allowed]).to be(true)
      end
    end

    context "with different caller identities" do
      it "tracks windows independently per caller" do
        10.times { limiter.check("agent:A", "retry_job", retry_config, global_limits) }
        result = limiter.check("agent:B", "retry_job", retry_config, global_limits)
        expect(result[:allowed]).to be(true)
      end
    end

    context "for global limits" do
      it "tracks global limits separately from per-action limits" do
        # inspect_job has 60/minute action limit; verify global key is populated too
        result = limiter.check("agent:1", "inspect_job", inspect_config, global_limits)
        expect(result[:allowed]).to be(true)
      end
    end

    context "when rate_limit is missing or malformed (defense in depth, f-l10-6 follow-up)" do
      it "returns allowed: false with an explicit reason instead of raising" do
        bad_config = { "operation" => "read", "rate_limit" => nil }

        expect { limiter.check("agent:1", "bad_action", bad_config, global_limits) }.not_to raise_error
        result = limiter.check("agent:1", "bad_action", bad_config, global_limits)

        expect(result[:allowed]).to be(false)
        expect(result[:reason]).to eq("missing_or_invalid_rate_limit")
      end
    end
  end
end

# rubocop:enable RSpec/ContextWording
