# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Wild::Telemetry::Collector::Store::JsonLinesStore do
  let(:tmpdir) { Dir.mktmpdir("json_lines_store_spec") }
  let(:store_path) { File.join(tmpdir, "events.jsonl") }
  let(:store) { described_class.new(path: store_path) }

  after { FileUtils.remove_entry(tmpdir) }

  describe "directory creation" do
    it "creates the parent directory when it does not exist" do
      nested_path = File.join(tmpdir, "a", "b", "c", "events.jsonl")
      described_class.new(path: nested_path)
      expect(File.directory?(File.dirname(nested_path))).to be(true)
    end
  end

  describe "#append" do
    let(:envelope) { build_envelope }

    it "writes a JSON line to the file" do
      store.append(envelope)
      expect(File.readlines(store_path).size).to eq(1)
    end

    it "returns the appended envelope" do
      result = store.append(envelope)
      expect(result).to eq(envelope)
    end
  end

  describe "#count" do
    context "when the file does not exist" do
      it "returns 0" do
        expect(store.count).to eq(0)
      end
    end

    context "when the file exists but has been cleared" do
      before do
        store.append(build_envelope)
        store.clear!
      end

      it "returns 0" do
        expect(store.count).to eq(0)
      end
    end

    context "with multiple appended envelopes" do
      it "returns the correct count" do
        store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z"))
        store.append(build_envelope(timestamp: "2026-03-19T10:00:01.000Z"))
        expect(store.count).to eq(2)
      end
    end
  end

  describe "#recent" do
    let(:envelope_a) { build_envelope(timestamp: "2026-03-19T10:00:00.000Z") }
    let(:envelope_b) { build_envelope(timestamp: "2026-03-19T10:00:01.000Z") }
    let(:envelope_c) { build_envelope(timestamp: "2026-03-19T10:00:02.000Z") }

    context "when the file does not exist" do
      it "returns an empty array" do
        expect(store.recent).to eq([])
      end
    end

    context "with multiple appended envelopes" do
      before do
        store.append(envelope_a)
        store.append(envelope_b)
        store.append(envelope_c)
      end

      it "returns envelopes in reverse-chronological order" do
        results = store.recent
        expect(results.first.timestamp).to eq(envelope_c.timestamp)
        expect(results.last.timestamp).to eq(envelope_a.timestamp)
      end

      it "respects the limit parameter" do
        results = store.recent(limit: 2)
        expect(results.size).to eq(2)
        expect(results.first.timestamp).to eq(envelope_c.timestamp)
      end
    end
  end

  describe "#find" do
    let(:envelope) { build_envelope(timestamp: "2026-03-19T10:00:00.000Z", event_type: "action.completed") }

    context "when the file does not exist" do
      it "returns nil" do
        expect(store.find(timestamp: "2026-03-19T10:00:00.000Z", event_type: "action.completed")).to be_nil
      end
    end

    context "with a stored envelope" do
      before { store.append(envelope) }

      it "locates the envelope by timestamp and event_type" do
        result = store.find(timestamp: envelope.timestamp, event_type: envelope.event_type)
        expect(result.timestamp).to eq(envelope.timestamp)
        expect(result.event_type).to eq(envelope.event_type)
      end

      it "returns nil for a non-existent combination" do
        result = store.find(timestamp: "1970-01-01T00:00:00.000Z", event_type: "action.completed")
        expect(result).to be_nil
      end
    end
  end

  describe "#query" do
    let(:envelope_action) do
      build_envelope(timestamp: "2026-03-19T10:00:00.000Z", event_type: "action.completed")
    end
    let(:envelope_gate) do
      build_envelope(timestamp: "2026-03-19T10:00:01.000Z", event_type: "gate.evaluated")
    end
    let(:envelope_rate) do
      build_envelope(timestamp: "2026-03-19T10:00:02.000Z", event_type: "rate_limit.checked")
    end

    before do
      store.append(envelope_action)
      store.append(envelope_gate)
      store.append(envelope_rate)
    end

    context "without filters" do
      it "returns all envelopes" do
        expect(store.query.size).to eq(3)
      end
    end

    context "when filtering by event_type" do
      it "returns only matching envelopes" do
        results = store.query(event_type: "action.completed")
        expect(results.size).to eq(1)
        expect(results.first.event_type).to eq("action.completed")
      end
    end

    context "when filtering by since" do
      it "excludes envelopes before the boundary" do
        results = store.query(since: "2026-03-19T10:00:01.000Z")
        expect(results.map(&:timestamp)).not_to include("2026-03-19T10:00:00.000Z")
        expect(results.size).to eq(2)
      end
    end

    context "when filtering by before" do
      it "excludes envelopes at or after the boundary" do
        results = store.query(before: "2026-03-19T10:00:02.000Z")
        expect(results.map(&:timestamp)).not_to include("2026-03-19T10:00:02.000Z")
        expect(results.size).to eq(2)
      end
    end

    context "with combined since and before filters" do
      it "returns only envelopes within the time range" do
        results = store.query(
          since: "2026-03-19T10:00:01.000Z",
          before: "2026-03-19T10:00:02.000Z"
        )
        expect(results.size).to eq(1)
        expect(results.first.timestamp).to eq(envelope_gate.timestamp)
      end
    end
  end

  describe "#clear!" do
    before do
      store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z"))
      store.append(build_envelope(timestamp: "2026-03-19T10:00:01.000Z"))
    end

    it "removes all events from the file" do
      store.clear!
      expect(store.count).to eq(0)
    end

    context "when the file does not exist" do
      it "does not raise" do
        FileUtils.rm_f(store_path)
        expect { store.clear! }.not_to raise_error
      end
    end
  end

  describe "#size_bytes" do
    context "when the file does not exist" do
      it "returns 0" do
        expect(store.size_bytes).to eq(0)
      end
    end

    context "when the file is empty" do
      before { store.clear! }

      it "returns 0" do
        File.write(store_path, "")
        expect(store.size_bytes).to eq(0)
      end
    end

    context "with appended envelopes" do
      it "returns the correct file size in bytes" do
        store.append(build_envelope)
        expect(store.size_bytes).to be > 0
        expect(store.size_bytes).to eq(File.size(store_path))
      end
    end
  end

  describe "thread safety" do
    it "does not lose data under concurrent appends" do
      threads = 20.times.map do |i|
        Thread.new do
          ts = format("2026-03-19T10:%02d:00.000Z", i)
          store.append(build_envelope(timestamp: ts))
        end
      end
      threads.each(&:join)
      expect(store.count).to eq(20)
    end
  end

  describe "error tolerance" do
    it "skips corrupted JSON lines without raising" do
      File.write(store_path, "not valid json\n")
      store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z"))
      expect { store.recent }.not_to raise_error
    end

    it "returns parseable envelopes even when some lines are corrupted" do
      File.write(store_path, "corrupted line\n")
      store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z"))
      results = store.recent
      expect(results.size).to eq(1)
    end
  end

  describe "#compact" do
    context "when the file does not exist" do
      it "returns 0 without yielding" do
        expect { |b| store.compact(&b) }.not_to yield_control
        expect(store.compact { |lines| lines }).to eq(0)
      end
    end

    context "when nothing is removed" do
      before { store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z")) }

      it "returns 0 and leaves the file unchanged" do
        result = store.compact { |lines| lines }
        expect(result).to eq(0)
        expect(store.count).to eq(1)
      end
    end

    context "when some lines are removed" do
      before do
        store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z"))
        store.append(build_envelope(timestamp: "2026-03-19T10:00:01.000Z"))
      end

      it "returns the count of removed lines and keeps the rest" do
        result = store.compact { |lines| lines.drop(1) }
        expect(result).to eq(1)
        expect(store.count).to eq(1)
      end
    end

    describe "crash safety (finding f-l02-2)" do
      before { store.append(build_envelope(timestamp: "2026-03-19T10:00:00.000Z")) }

      it "leaves the original file byte-for-byte intact when the rename step fails" do
        original_content = File.read(store_path)
        allow(File).to receive(:rename).and_raise(Errno::ENOSPC, "no space left on device")

        expect { store.compact { |_lines| [] } }.to raise_error(Errno::ENOSPC)
        expect(File.read(store_path)).to eq(original_content)
      end

      it "deletes the temp file it wrote before re-raising" do
        allow(File).to receive(:rename).and_raise(Errno::ENOSPC, "no space left on device")

        expect { store.compact { |_lines| [] } }.to raise_error(Errno::ENOSPC)
        leftovers = Dir.glob(File.join(tmpdir, "*.tmp-*"))
        expect(leftovers).to be_empty
      end
    end

    describe "concurrency safety (finding f-l02-1)" do
      it "does not lose events written by concurrent appends while a compact runs" do
        # Fails on main: RetentionManager (and any other #compact-shaped
        # rewrite) reads/writes @store.path directly, outside @mutex, so an
        # append landing mid-purge is built into a stale snapshot and lost.
        store.append(build_envelope(timestamp: "2026-03-19T09:00:00.000Z"))

        appender = Thread.new do
          50.times do |i|
            ts = format("2026-03-19T10:%02d:00.000Z", i)
            store.append(build_envelope(timestamp: ts))
          end
        end

        compactor = Thread.new do
          10.times do
            store.compact { |lines| lines } # no-op rewrite, still takes the lock + does the I/O
          end
        end

        [appender, compactor].each(&:join)

        expect(store.count).to eq(51)
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
