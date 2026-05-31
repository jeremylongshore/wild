# frozen_string_literal: true

RSpec.describe Wild::Analyzers::TestFlakes::Models::TestIdentity do
  subject(:identity) do
    described_class.new(file_path: "spec/models/user_spec.rb", test_name: "is valid", context: "User")
  end

  describe "#initialize" do
    it "stores file_path, test_name, and context" do
      expect(identity.file_path).to eq("spec/models/user_spec.rb")
      expect(identity.test_name).to eq("is valid")
      expect(identity.context).to eq("User")
    end

    it "allows nil context" do
      id = described_class.new(file_path: "spec/foo.rb", test_name: "does something")
      expect(id.context).to eq("")
    end

    it "raises ArgumentError for empty file_path" do
      expect { described_class.new(file_path: "", test_name: "test") }
        .to raise_error(ArgumentError)
    end

    it "raises ArgumentError for empty test_name" do
      expect { described_class.new(file_path: "spec/foo.rb", test_name: "") }
        .to raise_error(ArgumentError)
    end
  end

  describe "#key" do
    it "returns a composite string" do
      expect(identity.key).to eq("spec/models/user_spec.rb::User::is valid")
    end

    it "is consistent across calls" do
      key_a = identity.key
      key_b = identity.key
      expect(key_a).to eq(key_b)
    end
  end

  describe "#==" do
    it "is equal to an identity with same attributes" do
      other = described_class.new(
        file_path: "spec/models/user_spec.rb",
        test_name: "is valid",
        context: "User"
      )
      expect(identity).to eq(other)
    end

    it "is not equal with different test_name" do
      other = described_class.new(
        file_path: "spec/models/user_spec.rb",
        test_name: "is invalid",
        context: "User"
      )
      expect(identity).not_to eq(other)
    end
  end

  describe "#hash" do
    it "returns consistent hash for same identity" do
      other = described_class.new(
        file_path: "spec/models/user_spec.rb",
        test_name: "is valid",
        context: "User"
      )
      expect(identity.hash).to eq(other.hash)
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      expect(identity.to_h).to eq(
        file_path: "spec/models/user_spec.rb",
        test_name: "is valid",
        context: "User"
      )
    end
  end

  describe "#to_s" do
    it "includes file, context, and test name" do
      expect(identity.to_s).to include("spec/models/user_spec.rb")
      expect(identity.to_s).to include("User")
      expect(identity.to_s).to include("is valid")
    end

    it "omits context segment when context is empty" do
      id = described_class.new(file_path: "spec/foo.rb", test_name: "does something")
      expect(id.to_s).to eq("spec/foo.rb — does something")
    end
  end
end
