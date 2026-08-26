# frozen_string_literal: true

RSpec.describe Wild::Hooks::Audit::Sanitizer do
  subject(:sanitizer) { described_class.new }

  describe "#sanitize" do
    it "returns an empty hash when params are nil" do
      expect(sanitizer.sanitize(nil)).to eq({})
    end

    it "returns an empty hash when params are empty" do
      expect(sanitizer.sanitize({})).to eq({})
    end

    it "passes through values whose keys match no pattern" do
      expect(sanitizer.sanitize(name: "Alice", count: 42)).to eq(name: "Alice", count: 42)
    end

    describe "redaction" do
      it "redacts keys containing 'password'" do
        out = sanitizer.sanitize(password: "hunter2")
        expect(out[:password]).to eq(described_class::REDACTED)
      end

      it "redacts keys containing 'api_key' as a substring" do
        out = sanitizer.sanitize(stripe_api_key: "sk_live_abc")
        expect(out[:stripe_api_key]).to eq(described_class::REDACTED)
      end

      it "redacts email, phone, address by default" do
        out = sanitizer.sanitize(email: "a@b.com", phone: "555", address: "1 Main St")
        expect(out.values).to all(eq(described_class::REDACTED))
      end

      it "keeps exact operational keys despite overlapping substring patterns" do
        out = sanitizer.sanitize(
          max_tokens: 500, token_count: 42, ip_address: "203.0.113.8",
          email_template: "receipt", contractor_id: "contractor-7"
        )

        expect(out).to eq(
          max_tokens: 500, token_count: 42, ip_address: "203.0.113.8",
          email_template: "receipt", contractor_id: "contractor-7"
        )
      end
    end

    describe "hashing" do
      it "hashes keys containing 'user_id' to a SHA-256 prefix" do
        out = sanitizer.sanitize(user_id: 42)
        expect(out[:user_id]).to start_with(described_class::HASHED_PREFIX)
        expect(out[:user_id]).to end_with("]")
      end

      it "produces a stable digest for the same value" do
        a = sanitizer.sanitize(actor_id: "abc")[:actor_id]
        b = sanitizer.sanitize(actor_id: "abc")[:actor_id]
        expect(a).to eq(b)
      end

      it "produces different digests for different values" do
        a = sanitizer.sanitize(account_id: "alice")[:account_id]
        b = sanitizer.sanitize(account_id: "bob")[:account_id]
        expect(a).not_to eq(b)
      end
    end

    describe "recursion" do
      it "recurses into nested hashes" do
        nested = { outer: { password: "secret", count: 1 } }
        out = sanitizer.sanitize(nested)
        expect(out[:outer][:password]).to eq(described_class::REDACTED)
        expect(out[:outer][:count]).to eq(1)
      end

      it "does not mutate the input hash" do
        input = { password: "hunter2" }
        sanitizer.sanitize(input)
        expect(input[:password]).to eq("hunter2")
      end
    end

    describe "key coercion" do
      it "matches symbol and string keys identically" do
        sym = sanitizer.sanitize(password: "x")[:password]
        str = sanitizer.sanitize("password" => "x")["password"]
        expect(sym).to eq(str)
      end
    end

    describe "array recursion (f-l01 verifier follow-up 1)" do
      it "recurses into a hash nested inside an array value" do
        out = sanitizer.sanitize(params: [{ password: "p2" }])
        expect(out[:params].first[:password]).to eq(described_class::REDACTED)
      end

      it "recurses into arrays nested inside arrays" do
        out = sanitizer.sanitize(params: [[{ password: "p2" }]])
        expect(out[:params].first.first[:password]).to eq(described_class::REDACTED)
      end

      it "passes through scalar array elements unchanged" do
        out = sanitizer.sanitize(tags: %w[a b c])
        expect(out[:tags]).to eq(%w[a b c])
      end

      it "leaves non-matching hashes inside an array otherwise intact" do
        out = sanitizer.sanitize(params: [{ password: "p2", name: "Alice" }])
        expect(out[:params].first[:name]).to eq("Alice")
      end
    end

    describe "key normalization (f-l01 verifier follow-up 4)" do
      it "matches a camelCase key against the snake_case pattern" do
        out = sanitizer.sanitize(apiKey: "sk-live-abc")
        expect(out[:apiKey]).to eq(described_class::REDACTED)
      end

      it "matches an UPPER_SNAKE key against the snake_case pattern" do
        out = sanitizer.sanitize(API_KEY: "sk-live-abc")
        expect(out[:API_KEY]).to eq(described_class::REDACTED)
      end

      it "matches a hyphenated key against the snake_case pattern" do
        out = sanitizer.sanitize("api-key" => "sk-live-abc")
        expect(out["api-key"]).to eq(described_class::REDACTED)
      end

      it "matches a space-separated key against the snake_case pattern" do
        out = sanitizer.sanitize("Api Key" => "sk-live-abc")
        expect(out["Api Key"]).to eq(described_class::REDACTED)
      end
    end
  end

  describe "#sanitize_string (f-l01 verifier follow-up 2)" do
    it "redacts a password=value token inside free text" do
      out = sanitizer.sanitize_string("connection failed: password=hunter2")
      expect(out).not_to include("hunter2")
      expect(out).to include("password=[REDACTED]")
    end

    it "redacts a token=value token inside free text without disturbing surrounding words" do
      out = sanitizer.sanitize_string("auth error: api_key=sk-live-abc123 retrying")
      expect(out).to eq("auth error: api_key=[REDACTED] retrying")
    end

    it "leaves non-secret key=value tokens untouched" do
      out = sanitizer.sanitize_string("retries=3 timeout=500")
      expect(out).to eq("retries=3 timeout=500")
    end

    it "leaves plain text with no key=value shape untouched" do
      out = sanitizer.sanitize_string("boom")
      expect(out).to eq("boom")
    end

    it "returns nil unchanged" do
      expect(sanitizer.sanitize_string(nil)).to be_nil
    end
  end

  describe "custom patterns" do
    subject(:sanitizer) do
      described_class.new(redact_keys: %w[forbidden], hash_keys: %w[traceable])
    end

    it "honors the supplied redact_keys instead of defaults" do
      out = sanitizer.sanitize(forbidden_field: "x", password: "y")
      expect(out[:forbidden_field]).to eq(described_class::REDACTED)
      expect(out[:password]).to eq("y") # default pattern no longer active
    end

    it "honors the supplied hash_keys instead of defaults" do
      out = sanitizer.sanitize(traceable_value: 42, user_id: 42)
      expect(out[:traceable_value]).to start_with(described_class::HASHED_PREFIX)
      expect(out[:user_id]).to eq(42) # default pattern no longer active
    end
  end

  it "allows hooks consumers to extend the exact-key operational allowlist" do
    custom = described_class.new(allow_keys: %w[retry_token_count])

    expect(custom.sanitize(retry_token_count: 3)[:retry_token_count]).to eq(3)
  end
end
