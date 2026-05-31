# frozen_string_literal: true

RSpec.describe Wild::Introspection::Server::ToolHandler do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  let(:success_result) { { status: :ok, record: { "id" => 1, "name" => "Test" } } }
  let(:denial_result) { { status: :denied, reason: :model_not_allowed, message: "Not allowed" } }
  let(:not_found_result) { { status: :not_found, message: "Record not found" } }
  let(:error_result) { { status: :error, reason: :query_timeout, message: "Timed out" } }

  describe ".execute" do
    context "with a valid API key" do
      it "resolves identity, passes gate, yields context, and formats success" do
        response = described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: authenticated_server_context
        ) { |_ctx| success_result }

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("ok")
      end

      it "yields the resolved request context to the block" do
        yielded_ctx = nil

        described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: authenticated_server_context
        ) do |ctx|
          yielded_ctx = ctx
          success_result
        end

        expect(yielded_ctx).to be_a(Wild::Introspection::Identity::RequestContext)
        expect(yielded_ctx.caller_id).to eq("test-agent")
        expect(yielded_ctx.authenticated?).to be(true)
      end
    end

    context "with nil server_context" do
      it "resolves anonymous identity, gate denies, returns error response" do
        block_called = false

        response = described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: nil
        ) do
          block_called = true
          success_result
        end

        expect(block_called).to be(false)
        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
        expect(parsed[:reason]).to eq("insufficient_capability")
      end

      it "produces an audit record for the gate denial" do
        audit_entries = []
        allow(Wild::Introspection::Audit::AuditLogger).to receive(:log) do |record|
          audit_entries << record
        end

        described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: nil
        ) { success_result }

        expect(audit_entries.size).to eq(1)
        expect(audit_entries.first.caller_id).to eq("anonymous")
        expect(audit_entries.first.outcome).to eq("denied")
      end
    end

    context "with an invalid API key" do
      it "resolves invalid identity, gate denies, returns error response" do
        response = described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: { api_key: "sk-totally-bogus" }
        ) { success_result }

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "when guard returns denial" do
      it "formats with error: true" do
        response = described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: authenticated_server_context
        ) { |_ctx| denial_result }

        expect(response.error?).to be(true)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("denied")
      end
    end

    context "when guard returns not_found" do
      it "formats with error: false" do
        response = described_class.execute(
          action: "lookup_record_by_id",
          resource: "Account",
          server_context: authenticated_server_context
        ) { |_ctx| not_found_result }

        expect(response.error?).to be(false)

        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(parsed[:status]).to eq("not_found")
      end
    end

    context "when guard returns error" do
      it "formats with error: true" do
        response = described_class.execute(
          action: "find_records_by_filter",
          resource: "Account",
          server_context: authenticated_server_context
        ) { |_ctx| error_result }

        expect(response.error?).to be(true)
      end
    end

    context "with any valid response" do
      it "returns content as JSON text in MCP::Tool::Response" do
        response = described_class.execute(
          action: "inspect_model_schema",
          resource: "Account",
          server_context: authenticated_server_context
        ) { |_ctx| success_result }

        expect(response.content).to be_an(Array)
        expect(response.content.size).to eq(1)
        expect(response.content.first[:type]).to eq("text")
        expect { JSON.parse(response.content.first[:text]) }.not_to raise_error
      end
    end
  end
end
