# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording

RSpec.describe Wild::Introspection::Audit::ParameterSanitizer do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".sanitize" do
    context "for inspect_model_schema" do
      it "returns empty fields" do
        result = described_class.sanitize("inspect_model_schema", "Account", {})

        expect(result).to eq({ sanitized: true, fields: {} })
      end
    end

    context "for lookup_record_by_id" do
      it "includes the id" do
        result = described_class.sanitize("lookup_record_by_id", "Account", { id: 42 })

        expect(result).to eq({ sanitized: true, fields: { id: 42 } })
      end
    end

    context "for find_records_by_filter" do
      it "includes field and value for safe fields" do
        result = described_class.sanitize("find_records_by_filter", "Account", { field: "slug", value: "acme" })

        expect(result).to eq({ sanitized: true, fields: { field: "slug", value: "acme" } })
      end

      it "redacts value for blocked columns" do
        params = { field: "stripe_customer_id", value: "cus_secret" }
        result = described_class.sanitize("find_records_by_filter", "Account", params)

        expect(result[:fields][:value]).to eq("[REDACTED]")
        expect(result[:fields][:field]).to eq("stripe_customer_id")
      end

      it "redacts value for wildcard-blocked columns" do
        result = described_class.sanitize("find_records_by_filter", "Account", { field: "ssn", value: "999-99-9999" })

        expect(result[:fields][:value]).to eq("[REDACTED]")
      end

      it "does not leak blocked values in any field" do
        params = { field: "tax_id", value: "tax_secret456" }
        result = described_class.sanitize("find_records_by_filter", "Account", params)

        expect(result.to_s).not_to include("tax_secret456")
      end
    end
  end
end

# rubocop:enable RSpec/ContextWording
