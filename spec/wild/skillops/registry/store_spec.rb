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
    let(:class_comment) do
      source_file = described_class.instance_method(:add).source_location.first
      lines = File.readlines(source_file)
      class_line = lines.index { |l| l.include?("class Store") }
      lines[0...class_line].select { |l| l.strip.start_with?("#") }.join
    end

    it "no longer claims Store provides atomic read/write access" do
      expect(class_comment).not_to match(/provides? atomic/i)
    end

    it "states the actual guarantee: no atomicity/durability beyond plain Hash semantics" do
      expect(class_comment).to match(/no.+(atomicity|durability|thread-safety)/i)
    end
  end
end
