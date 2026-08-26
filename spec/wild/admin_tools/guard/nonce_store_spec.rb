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

  describe "#consume_if_unconsumed!" do
    context "for a stored, unconsumed nonce" do
      it "consumes it and returns true" do
        store.store(build_entry)
        expect(store.consume_if_unconsumed!("wnc_abc123")).to be(true)
        expect(store.fetch("wnc_abc123").consumed).to be(true)
      end
    end

    context "for an already-consumed nonce" do
      it "returns false without raising, instead of the old consume! which returned true again" do
        store.store(build_entry(consumed: true))
        expect(store.consume_if_unconsumed!("wnc_abc123")).to be(false)
      end
    end

    context "for an unknown nonce" do
      it "returns false" do
        expect(store.consume_if_unconsumed!("wnc_ghost")).to be(false)
      end
    end

    def race_consume(thread_count: 16)
      barrier = Queue.new
      results = Queue.new
      threads = Array.new(thread_count) do
        Thread.new do
          barrier.pop
          results << store.consume_if_unconsumed!("wnc_abc123")
        end
      end
      thread_count.times { barrier << true }
      threads.each(&:join)
      Array.new(thread_count) { results.pop }
    end

    it "lets exactly one of many concurrent callers win (finding f-l10-1)" do
      50.times do
        store.store(build_entry)
        expect(race_consume.count(true)).to eq(1)
        store.clear!
      end
    end
  end

  describe "#stop_sweep!" do
    it "does not raise when called on a fresh store" do
      fresh = described_class.new
      expect { fresh.stop_sweep! }.not_to raise_error
    end

    it "actually terminates the sweep thread promptly instead of leaving it asleep for up to 10s (f-l10-9)" do
      store.store(build_entry)
      sweep_thread = store.instance_variable_get(:@sweep_thread)
      store.stop_sweep!
      # Before the fix, the thread's loop body was `sleep 10; sweep_expired`
      # with no way to interrupt the sleep, so stop_sweep! could only ever
      # flip @running and `join(1)` -- a bounded wait that times out and
      # returns while the thread is still asleep for up to another ~10s.
      # The condition-variable broadcast wakes it immediately, so shortly
      # after stop_sweep! returns the thread must actually be dead.
      sleep 0.05
      expect(sweep_thread.alive?).to be(false)
    end

    it "spawns exactly one sweep thread even when #store is called concurrently by many threads" do
      fresh = described_class.new
      before_count = Thread.list.size

      barrier = Queue.new
      writers = Array.new(20) do |i|
        Thread.new do
          barrier.pop
          fresh.store(build_entry(nonce: "wnc_race_#{i}"))
        end
      end
      20.times { barrier << true }
      writers.each(&:join)

      # Before the fix, `start_sweep_thread unless @running` (the guard) ran
      # OUTSIDE @mutex, so many of these 20 threads could all observe
      # @running == false before any of them flipped it to true, each
      # spawning its own sweeper (finding f-l10-9). The guard now lives
      # inside the same @mutex.synchronize block that writes the entry, so
      # exactly one sweep thread must exist regardless of how many writers
      # race #store.
      expect(Thread.list.size).to eq(before_count + 1)
      fresh.stop_sweep!
    end
  end
end

# rubocop:enable RSpec/ContextWording
