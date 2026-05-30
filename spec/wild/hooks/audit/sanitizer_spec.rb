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
end
