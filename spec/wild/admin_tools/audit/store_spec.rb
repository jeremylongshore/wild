# frozen_string_literal: true

# rubocop:disable RSpec/MultipleDescribes

require "spec_helper"
require "tmpdir"

RSpec.describe Wild::AdminTools::Audit::MemoryStore do
  subject(:store) { described_class.new }

  let(:record) do
    Wild::AdminTools::Audit::Record.new(
      caller_id: "user_1",
      action: "retry_job",
      outcome: "success"
    )
  end

  describe "#append" do
    it "stores a record" do
      store.append(record)
      expect(store.count).to eq(1)
    end

    it "returns the record" do
      expect(store.append(record)).to eq(record)
    end
  end

  describe "#recent" do
    it "returns records in reverse chronological order" do
      r1 = Wild::AdminTools::Audit::Record.new(caller_id: "a", action: "x", outcome: "success")
      r2 = Wild::AdminTools::Audit::Record.new(caller_id: "b", action: "y", outcome: "denied")
      store.append(r1)
      store.append(r2)

      recent = store.recent(limit: 10)
      expect(recent.first.caller_id).to eq("b")
      expect(recent.last.caller_id).to eq("a")
    end

    it "respects limit" do
      5.times { |i| store.append(Wild::AdminTools::Audit::Record.new(caller_id: "u#{i}", action: "a", outcome: "success")) }
      expect(store.recent(limit: 2).size).to eq(2)
    end
  end

  describe "#find" do
    it "finds a record by id" do
      store.append(record)
      found = store.find(record.id)
      expect(found).to eq(record)
    end

    it "returns nil for unknown id" do
      expect(store.find("nonexistent")).to be_nil
    end
  end

  describe "#clear!" do
    it "removes all records" do
      store.append(record)
      store.clear!
      expect(store.count).to eq(0)
    end
  end

  describe "thread safety" do
    it "handles concurrent appends" do
      threads = 10.times.map do |i|
        Thread.new do
          store.append(Wild::AdminTools::Audit::Record.new(caller_id: "t#{i}", action: "a", outcome: "success"))
        end
      end
      threads.each(&:join)
      expect(store.count).to eq(10)
    end
  end
end

RSpec.describe Wild::AdminTools::Audit::JsonLinesStore do
  subject(:store) { described_class.new(path: log_path) }

  let(:tmpdir) { Dir.mktmpdir }
  let(:log_path) { File.join(tmpdir, "audit.jsonl") }

  let(:record) do
    Wild::AdminTools::Audit::Record.new(
      caller_id: "user_1",
      action: "retry_job",
      outcome: "success",
      category: "background_jobs",
      parameters: { queue: "default" }
    )
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#append" do
    it "writes a JSON line to the file" do
      store.append(record)
      lines = File.readlines(log_path)
      expect(lines.size).to eq(1)

      parsed = JSON.parse(lines.first)
      expect(parsed["action"]).to eq("retry_job")
    end

    it "appends without overwriting" do
      store.append(record)
      r2 = Wild::AdminTools::Audit::Record.new(caller_id: "u2", action: "toggle_flag", outcome: "success")
      store.append(r2)
      expect(File.readlines(log_path).size).to eq(2)
    end
  end

  describe "#recent" do
    it "returns records in reverse chronological order" do
      store.append(record)
      r2 = Wild::AdminTools::Audit::Record.new(caller_id: "u2", action: "toggle_flag", outcome: "denied")
      store.append(r2)

      recent = store.recent(limit: 10)
      expect(recent.first.action).to eq("toggle_flag")
      expect(recent.last.action).to eq("retry_job")
    end

    it "returns empty array when file does not exist" do
      fresh = described_class.new(path: File.join(tmpdir, "nonexistent.jsonl"))
      expect(fresh.recent).to eq([])
    end
  end

  describe "#find" do
    it "finds a record by id" do
      store.append(record)
      found = store.find(record.id)
      expect(found.action).to eq("retry_job")
    end

    it "returns nil for unknown id" do
      store.append(record)
      expect(store.find("nonexistent")).to be_nil
    end
  end

  describe "#count" do
    it "returns the number of records" do
      3.times { store.append(Wild::AdminTools::Audit::Record.new(caller_id: "x", action: "a", outcome: "success")) }
      expect(store.count).to eq(3)
    end

    it "returns 0 when file does not exist" do
      fresh = described_class.new(path: File.join(tmpdir, "missing.jsonl"))
      expect(fresh.count).to eq(0)
    end
  end
end

# rubocop:enable RSpec/MultipleDescribes
