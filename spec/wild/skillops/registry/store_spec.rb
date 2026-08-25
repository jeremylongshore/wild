# frozen_string_literal: true

RSpec.describe Wild::Skillops::Registry::Store do
  subject(:store) { described_class.new }

  let(:entry) { make_entry }

  describe "#add and #include?" do
    it "adds an entry and reports it as included" do
      store.add(entry)
      expect(store.include?(entry.name)).to be true
    end

    it "raises ValidationError for non-RegistryEntry argument" do
      expect { store.add("bad") }.to raise_error(Wild::Skillops::ValidationError)
    end

    it "raises RegistryCapacityError when capacity is exceeded" do
      Wild.configure { |c| c.skillops.max_skills = 2 }
      make_skill_set(count: 2).each { |s| store.add(make_entry(skill: s)) }
      extra = make_skill(name: "extra.skill")
      expect do
        store.add(make_entry(skill: extra))
      end.to raise_error(Wild::Skillops::RegistryCapacityError)
    end

    it "allows updating an existing entry without counting against capacity" do
      Wild.configure { |c| c.skillops.max_skills = 1 }
      store.add(entry)
      expect { store.add(entry) }.not_to raise_error
    end
  end

  describe "#fetch" do
    it "returns the entry by name" do
      store.add(entry)
      expect(store.fetch(entry.name)).to eq(entry)
    end

    it "raises NotFoundError for unknown name" do
      expect { store.fetch("nope") }.to raise_error(Wild::Skillops::NotFoundError)
    end
  end

  describe "#fetch_or_nil" do
    it "returns nil for unknown name" do
      expect(store.fetch_or_nil("nope")).to be_nil
    end
  end

  describe "#all" do
    it "returns all entries" do
      skill_set = make_skill_set(count: 3)
      skill_set.each { |s| store.add(make_entry(skill: s)) }
      expect(store.all.size).to eq(3)
    end
  end

  describe "#delete" do
    it "removes an entry" do
      store.add(entry)
      store.delete(entry.name)
      expect(store.include?(entry.name)).to be false
    end
  end

  describe "#size" do
    it "returns the number of entries" do
      make_skill_set(count: 4).each { |s| store.add(make_entry(skill: s)) }
      expect(store.size).to eq(4)
    end
  end

  describe "#names" do
    it "returns all skill names" do
      make_skill_set(count: 2).each { |s| store.add(make_entry(skill: s)) }
      expect(store.names.size).to eq(2)
    end
  end

  describe "class-level documentation truth (review wave f-l07-1 / f-l07-2)" do
    # Predicate under test: a comment block is honest about concurrency
    # guarantees if every sentence mentioning atomicity/durability/thread-
    # safety is a *disclaimer* ("no", "not", "never" in that same sentence),
    # never a bare positive claim ("guarantees atomic...", "provides durable
    # writes"). This is deliberately stricter than a single not-match check:
    # it catches a re-asserted lie placed anywhere in the block, not just
    # the exact phrasing that was removed.
    def dishonest_sentences(text)
      # Split on sentence-ending punctuation followed by whitespace; keep it
      # simple since the source is our own prose, not free-form input.
      sentences = text.split(/(?<=[.:])\s+/)
      sentences.select do |sentence|
        sentence.match?(/atomic|durab|thread.?safe/i) &&
          !sentence.match?(/\bno\b|\bnot\b|\bnever\b/i)
      end
    end

    let(:class_comment) do
      source_file, = Object.const_source_location("Wild::Skillops::Registry::Store")
      lines = File.readlines(source_file)
      class_line = lines.index { |l| l.include?("class Store") }
      comment_lines = lines[0...class_line].reverse.take_while { |l| l.strip.start_with?("#") }.reverse
      comment_lines.map { |l| l.strip.sub(/\A#\s?/, "") }.join(" ")
    end

    it "no longer claims Store provides atomic read/write access" do
      expect(class_comment).not_to match(/provides? atomic/i)
    end

    it "states the actual guarantee: no atomicity, durability, or thread-safety guarantees" do
      expect(class_comment).to match(/no atomicity, durability, or thread-safety guarantees/i)
    end

    it "contains no undisclaimed positive concurrency-safety claim anywhere in the block" do
      expect(dishonest_sentences(class_comment)).to be_empty
    end

    it "the dishonest-sentence predicate actually catches a re-asserted lie (negative fixture)" do
      lie = "This store guarantees atomic read/write access and provides thread-safe durability."
      expect(dishonest_sentences(lie)).not_to be_empty
    end
  end
end
