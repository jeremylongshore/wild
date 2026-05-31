# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::AdminTools::Guard::NonceStore do
  subject(:store) { described_class.new }

  after { store.stop_sweep! }

  def build_entry(nonce: "wnc_abc123", consumed: false)
    Wild::AdminTools::Guard::NonceEntry.new(
      nonce: nonce,
      binding_hash: "deadbeef",
      action_name: "retry_job",
      caller_id: "agent:1",
      expires_at: Time.now.utc + 30,
      consumed: consumed
    )
  end

  describe "#store and #fetch" do
    it "stores an entry and retrieves it by nonce" do
      entry = build_entry
      store.store(entry)
      fetched = store.fetch("wnc_abc123")
      expect(fetched.nonce).to eq("wnc_abc123")
      expect(fetched.action_name).to eq("retry_job")
    end
  end

  describe "#fetch" do
    context "for an unknown nonce" do
      it "returns nil" do
        expect(store.fetch("wnc_unknown")).to be_nil
      end
    end
  end

  describe "#consume!" do
    context "for a stored nonce" do
      it "marks the entry as consumed and returns true" do
        store.store(build_entry)
        result = store.consume!("wnc_abc123")
        expect(result).to be(true)
        expect(store.fetch("wnc_abc123").consumed).to be(true)
      end
    end

    context "for an unknown nonce" do
      it "returns false" do
        expect(store.consume!("wnc_ghost")).to be(false)
      end
    end
  end

  describe "#size" do
    it "tracks the number of stored entries" do
      store.store(build_entry(nonce: "wnc_one"))
      store.store(build_entry(nonce: "wnc_two"))
      expect(store.size).to eq(2)
    end
  end

  describe "#clear!" do
    it "removes all stored entries" do
      store.store(build_entry)
      store.clear!
      expect(store.size).to eq(0)
    end
  end

  describe "#stop_sweep!" do
    it "does not raise when called on a fresh store" do
      fresh = described_class.new
      expect { fresh.stop_sweep! }.not_to raise_error
    end
  end
end

# rubocop:enable RSpec/ContextWording
