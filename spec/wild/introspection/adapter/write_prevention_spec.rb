# frozen_string_literal: true

RSpec.describe Wild::Introspection::Adapter::WritePrevention do
  describe ".write_method?" do
    it "returns true for all forbidden methods" do
      described_class::FORBIDDEN_METHODS.each do |method|
        expect(described_class.write_method?(method)).to be(true), "Expected #{method} to be forbidden"
      end
    end

    it "returns false for read methods" do
      %i[find find_by where all first last count pluck select].each do |method|
        expect(described_class.write_method?(method)).to be(false), "Expected #{method} to NOT be forbidden"
      end
    end

    it "accepts string method names" do
      expect(described_class.write_method?("save")).to be(true)
      expect(described_class.write_method?("find")).to be(false)
    end
  end

  describe ".assert_not_write_method!" do
    it "raises WriteAttemptError for forbidden methods" do
      expect do
        described_class.assert_not_write_method!(:save)
      end.to raise_error(Wild::Introspection::WriteAttemptError, /save/)
    end

    it "does not raise for read methods" do
      expect { described_class.assert_not_write_method!(:find) }.not_to raise_error
    end
  end

  describe ".assert_sql_read_only!" do
    it "raises WriteAttemptError for INSERT SQL" do
      expect do
        described_class.assert_sql_read_only!('INSERT INTO users (name) VALUES ("test")')
      end.to raise_error(Wild::Introspection::WriteAttemptError)
    end

    it "raises WriteAttemptError for UPDATE SQL" do
      expect do
        described_class.assert_sql_read_only!('UPDATE users SET name = "test"')
      end.to raise_error(Wild::Introspection::WriteAttemptError)
    end

    it "raises WriteAttemptError for DELETE SQL" do
      expect do
        described_class.assert_sql_read_only!("DELETE FROM users WHERE id = 1")
      end.to raise_error(Wild::Introspection::WriteAttemptError)
    end

    it "raises WriteAttemptError for DROP SQL" do
      expect do
        described_class.assert_sql_read_only!("DROP TABLE users")
      end.to raise_error(Wild::Introspection::WriteAttemptError)
    end

    it "does not raise for SELECT SQL" do
      expect { described_class.assert_sql_read_only!("SELECT * FROM users") }.not_to raise_error
    end

    it "does not raise for nil input" do
      expect { described_class.assert_sql_read_only!(nil) }.not_to raise_error
    end
  end

  describe "FORBIDDEN_METHODS completeness" do
    it "includes all methods from the safety model" do
      expected = %i[
        save save! create create! update update! update_all
        destroy destroy! destroy_all delete delete_all
        insert insert_all upsert upsert_all
        touch increment! decrement! toggle!
      ]

      expected.each do |method|
        expect(described_class::FORBIDDEN_METHODS).to(
          include(method), "Missing forbidden method: #{method}"
        )
      end
    end
  end
end
