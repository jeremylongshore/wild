# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Guard::NonceManager do
  subject(:manager) { described_class.new(store: store) }

  let(:store)       { Wild::AdminTools::Guard::NonceStore.new }
  let(:action_name) { "retry_job" }
  let(:params)      { { job_id: "job_abc" } }
  let(:caller_id)   { "agent:1" }

  after { store.stop_sweep! }

  describe "#generate" do
    it "returns a string starting with 'wnc_'" do
      nonce = manager.generate(action_name, params, caller_id)
      expect(nonce).to start_with("wnc_")
    end

    it "returns a unique nonce on each call" do
      nonces = Array.new(5) { manager.generate(action_name, params, caller_id) }
      expect(nonces.uniq.size).to eq(5)
    end
  end

  describe "#validate_and_consume!" do
    context "when nonce, action, params, and caller all match" do
      it "returns valid: true" do
        nonce = manager.generate(action_name, params, caller_id)
        result = manager.validate_and_consume!(nonce, action_name, params, caller_id)
        expect(result[:valid]).to be(true)
      end
    end

    context "when the action name does not match" do
      it "returns valid: false with client_reason nonce_invalid" do
        nonce = manager.generate(action_name, params, caller_id)
        result = manager.validate_and_consume!(nonce, "discard_job", params, caller_id)
        expect(result[:valid]).to be(false)
        expect(result[:client_reason]).to eq("nonce_invalid")
      end
    end

    context "when the params do not match" do
      it "returns valid: false" do
        nonce = manager.generate(action_name, params, caller_id)
        result = manager.validate_and_consume!(nonce, action_name, { job_id: "different" }, caller_id)
        expect(result[:valid]).to be(false)
      end
    end

    context "when the caller_id does not match" do
      it "returns valid: false" do
        nonce = manager.generate(action_name, params, caller_id)
        result = manager.validate_and_consume!(nonce, action_name, params, "agent:impostor")
        expect(result[:valid]).to be(false)
      end
    end

    context "when the nonce has already been consumed" do
      it "returns valid: false on the second attempt" do
        nonce = manager.generate(action_name, params, caller_id)
        manager.validate_and_consume!(nonce, action_name, params, caller_id)
        result = manager.validate_and_consume!(nonce, action_name, params, caller_id)
        expect(result[:valid]).to be(false)
      end
    end

    context "when the nonce has expired" do
      it "returns valid: false" do
        nonce = manager.generate(action_name, params, caller_id, ttl_seconds: 10)
        entry = store.fetch(nonce)
        expired_entry = Wild::AdminTools::Guard::NonceEntry.new(
          nonce: entry.nonce,
          binding_hash: entry.binding_hash,
          action_name: entry.action_name,
          caller_id: entry.caller_id,
          expires_at: Time.now.utc - 1,
          consumed: entry.consumed
        )
        store.store(expired_entry)
        result = manager.validate_and_consume!(nonce, action_name, params, caller_id)
        expect(result[:valid]).to be(false)
      end
    end

    context "when the nonce does not exist in the store" do
      it "returns valid: false" do
        result = manager.validate_and_consume!("wnc_ghost_nonce", action_name, params, caller_id)
        expect(result[:valid]).to be(false)
      end
    end

    context "when N threads race to confirm the same nonce concurrently (finding f-l10-1)" do
      # Before the fix, #validate_and_consume! was check-then-act across
      # three separate NonceStore mutex acquisitions (fetch, test
      # entry.consumed, then consume!), so multiple threads could all
      # observe consumed == false before any of them called consume!, and
      # all received valid: true -- double-executing whatever
      # mutate_destructive action the nonce was gating. This fails on main
      # nondeterministically (run with --seed 1 and --seed 41803 both
      # reproduce it), so it is run many times to make the flake reliable.
      # Fires 16 threads at once (via a barrier so they truly race rather
      # than run near-serially) and returns the array of `valid:` outcomes.
      # Popping the results Queue 16 times blocks until all 16 threads have
      # pushed, so no separate Thread#join bookkeeping is needed.
      def race_confirms(nonce)
        barrier = Queue.new
        results = Queue.new
        16.times do
          Thread.new do
            barrier.pop
            results << validate(nonce)
          end
        end
        16.times { barrier << true }
        Array.new(16) { results.pop }
      end

      def validate(nonce)
        manager.validate_and_consume!(nonce, action_name, params, caller_id)[:valid]
      end

      it "lets exactly one thread win, every time" do
        50.times do
          nonce = manager.generate(action_name, params, caller_id)
          outcomes = race_confirms(nonce)
          expect(outcomes.count(true)).to eq(1),
                                          "expected exactly one winner among 16 concurrent confirms of one " \
                                          "nonce, got #{outcomes.count(true)}"
        end
      end
    end
  end
end
