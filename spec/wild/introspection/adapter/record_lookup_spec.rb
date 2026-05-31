# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Adapter::RecordLookup do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:account) { Account.create!(name: "Test Corp", slug: "test-corp", plan: "pro") }

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    User.create!(account: account, email: "alice@example.com", name: "Alice", status: "active")
  end

  describe ".find_by_id" do
    context "for an allowed model with an existing record" do
      it "returns the record as a hash" do
        result = described_class.find_by_id("Account", account.id)

        expect(result[:status]).to eq(:ok)
        expect(result[:record]["name"]).to eq("Test Corp")
        expect(result[:record]["slug"]).to eq("test-corp")
      end
    end

    context "for an allowed model with a nonexistent ID" do
      it "returns not_found" do
        result = described_class.find_by_id("Account", 999_999)

        expect(result[:status]).to eq(:not_found)
        expect(result[:message]).to eq("No record found.")
      end
    end

    context "for a blocked model" do
      it "returns denial" do
        result = described_class.find_by_id("CreditCard", 1)

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    context "for a nonexistent model" do
      it "returns denial" do
        result = described_class.find_by_id("TotallyFakeModel", 1)

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    it "returns identical denial responses for blocked, nonexistent, and unlisted models" do
      blocked = described_class.find_by_id("CreditCard", 1)
      nonexistent = described_class.find_by_id("TotallyFakeModel", 1)
      unlisted = described_class.find_by_id("ApiKey", 1)

      expect(blocked).to eq(nonexistent)
      expect(blocked).to eq(unlisted)
    end

    it "does not reveal the model name in denial messages" do
      result = described_class.find_by_id("CreditCard", 1)

      expect(result[:message]).not_to include("CreditCard")
    end

    it "does not reveal the model name in not-found messages" do
      result = described_class.find_by_id("Account", 999_999)

      expect(result[:message]).not_to include("Account")
    end

    it "uses parameterized queries" do
      queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql]
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.find_by_id("Account", account.id)
      end

      select_queries = queries.grep(/SELECT/i)
      select_queries.each do |sql|
        expect(sql).not_to include("'#{account.id}'")
      end
    end
  end
end

# rubocop:enable RSpec/ContextWording
