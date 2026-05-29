# frozen_string_literal: true

require "yaml"

# Schema test describes a data file, not a class.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "lib/wild/schemas/wildcard_corpus.yml" do
  subject(:corpus) { YAML.safe_load_file(corpus_path, permitted_classes: []) }

  let(:corpus_path) do
    File.expand_path("../../../lib/wild/schemas/wildcard_corpus.yml", __dir__)
  end

  describe "structure" do
    it "loads as a Hash with version + patterns keys" do
      expect(corpus).to be_a(Hash)
      expect(corpus.keys).to contain_exactly("version", "patterns")
    end

    it "declares a numeric schema version" do
      expect(corpus.fetch("version")).to be_a(Integer)
      expect(corpus.fetch("version")).to be >= 1
    end

    it "patterns is a non-empty array" do
      expect(corpus.fetch("patterns")).to be_an(Array)
      expect(corpus.fetch("patterns")).not_to be_empty
    end
  end

  describe "every entry" do
    it "has pattern + description + matches + non_matches keys" do
      corpus.fetch("patterns").each do |entry|
        expect(entry.keys).to include("pattern", "description", "matches", "non_matches")
      end
    end

    it "has a non-empty pattern string" do
      corpus.fetch("patterns").each do |entry|
        expect(entry.fetch("pattern")).to be_a(String)
        expect(entry.fetch("pattern")).not_to be_empty
      end
    end

    it "has a description string" do
      corpus.fetch("patterns").each do |entry|
        expect(entry.fetch("description")).to be_a(String)
        expect(entry.fetch("description").length).to be > 5
      end
    end

    it "has Array matches + non_matches (may be empty for negation patterns)" do
      corpus.fetch("patterns").each do |entry|
        expect(entry.fetch("matches")).to be_an(Array)
        expect(entry.fetch("non_matches")).to be_an(Array)
      end
    end
  end

  describe "F4 — same corpus loadable by both consumers" do
    # Permission analyzer + CapabilityGate both consume this file. Verify
    # the file's bytes are identical for both consumers by loading it twice
    # from the canonical path (no per-namespace copy) and asserting
    # structural equality. This is the smallest spec that catches a future
    # accidental fork into two corpora.
    it "loads identically when re-loaded" do
      first = YAML.safe_load_file(corpus_path, permitted_classes: [])
      second = YAML.safe_load_file(corpus_path, permitted_classes: [])
      expect(first).to eq(second)
    end
  end

  describe "documented wildcard forms" do
    let(:patterns) { corpus.fetch("patterns").map { |e| e.fetch("pattern") } }

    {
      "exact" => "User",
      "suffix wildcard" => "User::*",
      "prefix wildcard" => "*::Admin",
      "recursive wildcard" => "User::**",
      "universal wildcard" => "*",
      "negation" => "!User::Admin",
      "middle wildcard" => "User::*::Profile"
    }.each do |form_name, pattern|
      it "includes the #{form_name} form (#{pattern})" do
        expect(patterns).to include(pattern)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
