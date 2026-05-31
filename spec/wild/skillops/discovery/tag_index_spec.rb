# frozen_string_literal: true

RSpec.describe Wild::Skillops::Discovery::TagIndex do
  subject(:index) { described_class.new }

  describe "#index and #lookup" do
    it "indexes tags for a skill and allows lookup" do
      index.index("my.skill", %w[alpha beta])
      expect(index.lookup("alpha")).to include("my.skill")
      expect(index.lookup("beta")).to include("my.skill")
    end

    it "normalizes tags to lowercase" do
      index.index("my.skill", ["Alpha"])
      expect(index.lookup("alpha")).to include("my.skill")
    end

    it "strips whitespace from tags" do
      index.index("my.skill", [" spaced "])
      expect(index.lookup("spaced")).to include("my.skill")
    end

    it "does not duplicate skill names for the same tag" do
      index.index("my.skill", ["dupe"])
      index.index("my.skill", ["dupe"])
      expect(index.lookup("dupe").count { |n| n == "my.skill" }).to eq(1)
    end

    it "returns empty array for unknown tag" do
      expect(index.lookup("zzz")).to eq([])
    end
  end

  describe "#reindex" do
    it "removes old tags and adds new tags" do
      index.index("my.skill", ["old"])
      index.reindex("my.skill", old_tags: ["old"], new_tags: ["new"])
      expect(index.lookup("old")).not_to include("my.skill")
      expect(index.lookup("new")).to include("my.skill")
    end

    it "preserves tags common to both old and new" do
      index.index("my.skill", %w[common removed])
      index.reindex("my.skill", old_tags: %w[common removed], new_tags: %w[common added])
      expect(index.lookup("common")).to include("my.skill")
      expect(index.lookup("removed")).not_to include("my.skill")
      expect(index.lookup("added")).to include("my.skill")
    end
  end

  describe "#remove_skill" do
    it "removes skill from all tag entries" do
      index.index("my.skill", %w[x y z])
      index.remove_skill("my.skill")
      expect(index.lookup("x")).not_to include("my.skill")
      expect(index.lookup("y")).not_to include("my.skill")
    end
  end

  describe "#all_tags" do
    it "returns all indexed tags sorted" do
      index.index("a", %w[beta alpha])
      expect(index.all_tags).to eq(%w[alpha beta])
    end
  end
end
