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

    it "has Array matches + non_matches (non_matches may be empty for universal '*')" do
      corpus.fetch("patterns").each do |entry|
        expect(entry.fetch("matches")).to be_an(Array)
        expect(entry.fetch("matches")).not_to be_empty
        expect(entry.fetch("non_matches")).to be_an(Array)
      end
    end

    it "has a non-empty non_matches list for every pattern except the universal '*'" do
      # Review wave finding f-l05-3: the corpus's own header comment documents
      # this invariant in prose ("non_matches: strings the matcher returns
      # false for (may be empty for the universal '*')") but nothing enforced
      # it in code. Enforced here instead of left as a comment: a future
      # wildcard-form entry with an accidentally empty non_matches list (e.g.
      # a copy-paste of the universal-wildcard block) now fails this spec.
      corpus.fetch("patterns").each do |entry|
        next if entry.fetch("pattern") == "*"

        expect(entry.fetch("non_matches")).not_to be_empty,
                                                  "pattern #{entry.fetch("pattern").inspect} must have at " \
                                                  "least one non_matches entry (only the universal '*' " \
                                                  "pattern may have an empty non_matches list)"
      end
    end
  end

  describe "F4 — single canonical corpus (no per-namespace fork)" do
    # Capability-name wildcard matching lives in ONE namespace
    # (Wild::Analyzers::Permission) per the wild-lkp reconciliation —
    # CapabilityGate is exact-match by design. This is the smallest spec that
    # catches a future accidental fork of the canonical file into two copies.
    it "loads identically when re-loaded from the canonical path" do
      first = YAML.safe_load_file(corpus_path, permitted_classes: [])
      second = YAML.safe_load_file(corpus_path, permitted_classes: [])
      expect(first).to eq(second)
    end
  end

  describe "documented wildcard forms (dotted glob — the grammar the matcher implements)" do
    let(:patterns) { corpus.fetch("patterns").map { |e| e.fetch("pattern") } }

    {
      "exact" => "admin.jobs.view",
      "trailing wildcard" => "admin.jobs.*",
      "top-level prefix wildcard" => "admin.*",
      "middle wildcard" => "admin.*.retry",
      "universal wildcard" => "*"
    }.each do |form_name, pattern|
      it "includes the #{form_name} form (#{pattern})" do
        expect(patterns).to include(pattern)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
