# frozen_string_literal: true

RSpec.describe Wild::Introspection::Guard::ResultFilter do
  let(:accessible_columns) { %w[id name email] }

  describe ".filter_record" do
    it "keeps only accessible columns" do
      record = { "id" => 1, "name" => "Alice", "email" => "a@b.com", "password_digest" => "secret" }

      result = described_class.filter_record(record, accessible_columns)

      expect(result).to eq("id" => 1, "name" => "Alice", "email" => "a@b.com")
    end

    it "silently drops blocked columns with no marker" do
      record = { "id" => 1, "ssn" => "123-45-6789", "name" => "Alice" }

      result = described_class.filter_record(record, accessible_columns)

      expect(result.keys).not_to include("ssn")
      expect(result.values).not_to include("123-45-6789")
    end

    it "handles empty accessible columns" do
      record = { "id" => 1, "name" => "Alice" }

      result = described_class.filter_record(record, [])

      expect(result).to be_empty
    end

    it "handles empty record" do
      result = described_class.filter_record({}, accessible_columns)

      expect(result).to be_empty
    end
  end

  describe ".filter_records" do
    it "filters each record in the array" do
      records = [
        { "id" => 1, "name" => "Alice", "password_digest" => "x" },
        { "id" => 2, "name" => "Bob", "password_digest" => "y" }
      ]

      result = described_class.filter_records(records, accessible_columns)

      expect(result).to eq([
                             { "id" => 1, "name" => "Alice" },
                             { "id" => 2, "name" => "Bob" }
                           ])
    end

    it "handles empty array" do
      expect(described_class.filter_records([], accessible_columns)).to eq([])
    end
  end

  describe ".filter_schema_columns" do
    it "keeps only columns whose name is in the accessible set" do
      columns = [
        { name: "id", type: :integer, sql_type: "INTEGER", nullable: false, default: nil },
        { name: "name", type: :string, sql_type: "VARCHAR", nullable: false, default: nil },
        { name: "password_digest", type: :string, sql_type: "VARCHAR", nullable: true, default: nil }
      ]

      result = described_class.filter_schema_columns(columns, accessible_columns)

      expect(result.pluck(:name)).to eq(%w[id name])
    end

    it "handles empty columns array" do
      expect(described_class.filter_schema_columns([], accessible_columns)).to eq([])
    end
  end
end
