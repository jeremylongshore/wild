# frozen_string_literal: true

RSpec.describe Wild::Introspection::Audit::AuditRecord do
  subject(:record) do
    described_class.new(
      tool_name: "inspect_model_schema",
      guard_result: "allowed",
      outcome: "success",
      duration_ms: 12,
      model_name: "Account"
    )
  end

  describe "auto-generated fields" do
    it "generates a UUID id" do
      expect(record.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "generates an ISO 8601 timestamp" do
      expect(record.timestamp).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/)
    end
  end

  describe "default fields" do
    it "defaults caller_id to anonymous" do
      expect(record.caller_id).to eq("anonymous")
    end

    it "defaults caller_type to unknown" do
      expect(record.caller_type).to eq("unknown")
    end

    it "sets server_version from VERSION constant" do
      expect(record.server_version).to eq(Wild::VERSION)
    end

    it "defaults rows_returned to 0" do
      expect(record.rows_returned).to eq(0)
    end

    it "defaults truncated to false" do
      expect(record.truncated).to be(false)
    end

    it "defaults error_message to nil" do
      expect(record.error_message).to be_nil
    end

    it "defaults read_replica_used to false" do
      expect(record.read_replica_used).to be(false)
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      hash = record.to_h

      described_class::FIELDS.each do |field|
        expect(hash).to have_key(field), "expected to_h to include #{field}"
      end
    end

    it "includes the correct values" do
      hash = record.to_h

      expect(hash[:tool_name]).to eq("inspect_model_schema")
      expect(hash[:model_name]).to eq("Account")
      expect(hash[:guard_result]).to eq("allowed")
      expect(hash[:outcome]).to eq("success")
      expect(hash[:duration_ms]).to eq(12)
    end
  end

  describe "immutability" do
    it "is frozen after construction" do
      expect(record).to be_frozen
    end
  end

  describe "custom field values" do
    subject(:custom) do
      described_class.new(
        tool_name: "lookup_record_by_id",
        guard_result: "denied_model_not_allowed",
        outcome: "denied",
        duration_ms: 5,
        model_name: "CreditCard",
        rows_returned: 0,
        truncated: false,
        error_message: "not allowed",
        read_replica_used: true,
        caller_id: "agent-1",
        caller_type: "api_key",
        parameters: { sanitized: true, fields: { id: 42 } }
      )
    end

    it "accepts custom caller_id" do
      expect(custom.caller_id).to eq("agent-1")
    end

    it "accepts custom caller_type" do
      expect(custom.caller_type).to eq("api_key")
    end

    it "accepts custom read_replica_used" do
      expect(custom.read_replica_used).to be(true)
    end

    it "accepts custom error_message" do
      expect(custom.error_message).to eq("not allowed")
    end

    it "accepts custom parameters" do
      expect(custom.parameters).to eq({ sanitized: true, fields: { id: 42 } })
    end
  end
end
