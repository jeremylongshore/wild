# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Adapter::SchemaInspector do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".inspect_schema" do
    context "for an allowed model" do
      let(:result) { described_class.inspect_schema("Account") }

      it "returns ok status" do
        expect(result[:status]).to eq(:ok)
      end

      it "returns the model name and table name" do
        expect(result[:model]).to eq("Account")
        expect(result[:table_name]).to eq("accounts")
      end

      it "returns column metadata" do
        columns = result[:columns]
        name_col = columns.find { |c| c[:name] == "name" }

        expect(name_col).to include(
          type: :string,
          nullable: false
        )
      end

      it "returns all columns from the table" do
        column_names = result[:columns].pluck(:name)
        expect(column_names).to include("id", "name", "slug", "plan", "created_at", "updated_at")
      end

      it "returns association metadata" do
        associations = result[:associations]
        users_assoc = associations.find { |a| a[:name] == "users" }

        expect(users_assoc).to include(
          type: :has_many,
          target_model: "User",
          foreign_key: "account_id"
        )
      end
    end

    context "for a model with no associations" do
      let(:result) { described_class.inspect_schema("FeatureFlag") }

      it "returns an empty associations array" do
        expect(result[:associations]).to eq([])
      end
    end

    context "for a blocked model" do
      it "returns a denial response" do
        result = described_class.inspect_schema("CreditCard")

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    context "for a nonexistent model" do
      it "returns the same denial as a blocked model" do
        blocked = described_class.inspect_schema("CreditCard")
        nonexistent = described_class.inspect_schema("TotallyFakeModel")

        expect(blocked).to eq(nonexistent)
      end
    end

    it "does not execute data queries" do
      queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql]
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.inspect_schema("Account")
      end

      data_queries = queries.grep_v(/pragma|sqlite_master/i)
      expect(data_queries).to be_empty
    end
  end
end

# rubocop:enable RSpec/ContextWording
