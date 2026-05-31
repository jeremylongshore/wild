# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Adapter::FilteredLookup do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before do
    configure_with_test_fixtures!
    User.delete_all
    Account.delete_all
    FeatureFlag.delete_all
    alpha = Account.create!(name: "Alpha Corp", slug: "alpha", plan: "pro")
    beta = Account.create!(name: "Beta Inc", slug: "beta", plan: "free")
    User.create!(account: alpha, email: "alice@alpha.com", name: "Alice", status: "active")
    User.create!(account: alpha, email: "bob@alpha.com", name: "Bob", status: "active")
    User.create!(account: beta, email: "carol@beta.com", name: "Carol", status: "inactive")
  end

  describe ".find_by_filter" do
    context "for an allowed model with matching records" do
      it "returns matching records" do
        result = described_class.find_by_filter("User", field: "status", value: "active")

        expect(result[:status]).to eq(:ok)
        expect(result[:records].size).to eq(2)
        expect(result[:truncated]).to be(false)
      end
    end

    context "for an allowed model with no matching records" do
      it "returns empty array" do
        result = described_class.find_by_filter("User", field: "status", value: "banned")

        expect(result[:status]).to eq(:ok)
        expect(result[:records]).to be_empty
        expect(result[:count]).to eq(0)
        expect(result[:truncated]).to be(false)
      end
    end

    context "for a blocked model" do
      it "returns denial" do
        result = described_class.find_by_filter("CreditCard", field: "number", value: "1234")

        expect(result[:status]).to eq(:denied)
        expect(result[:reason]).to eq(:model_not_allowed)
      end
    end

    context "for a nonexistent model" do
      it "returns denial identical to blocked model" do
        blocked = described_class.find_by_filter("CreditCard", field: "number", value: "1234")
        nonexistent = described_class.find_by_filter("FakeModel", field: "id", value: "1")

        expect(blocked).to eq(nonexistent)
      end
    end

    context "with an invalid field name" do
      it "returns denial" do
        result = described_class.find_by_filter("Account", field: "nonexistent_column", value: "test")

        expect(result[:status]).to eq(:denied)
      end

      it "returns the same denial format as model denial" do
        invalid_field = described_class.find_by_filter("Account", field: "fake_column", value: "test")
        blocked_model = described_class.find_by_filter("CreditCard", field: "number", value: "1234")

        expect(invalid_field[:status]).to eq(blocked_model[:status])
        expect(invalid_field[:reason]).to eq(blocked_model[:reason])
      end
    end

    context "with row cap enforcement" do
      before do
        55.times { |i| FeatureFlag.create!(key: "flag_#{i}", enabled: true) }
      end

      it "truncates results when exceeding max_rows" do
        result = described_class.find_by_filter("FeatureFlag", field: "enabled", value: true)

        expect(result[:status]).to eq(:ok)
        expect(result[:records].size).to eq(50)
        expect(result[:truncated]).to be(true)
        expect(result[:count]).to eq(50)
      end
    end

    context "with hard row ceiling" do
      it "respects the hard ceiling of 1000" do
        expect(described_class::HARD_ROW_CEILING).to eq(1000)
      end
    end

    it "does not reveal model names in denial messages" do
      result = described_class.find_by_filter("CreditCard", field: "number", value: "1234")

      expect(result[:message]).not_to include("CreditCard")
    end

    it "uses parameterized queries" do
      queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql]
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.find_by_filter("User", field: "status", value: "active")
      end

      select_queries = queries.grep(/SELECT/i)
      select_queries.each do |sql|
        expect(sql).not_to include("'active'")
      end
    end
  end
end

# rubocop:enable RSpec/ContextWording
