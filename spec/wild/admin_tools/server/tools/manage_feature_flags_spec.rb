# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Server::Tools::ManageFeatureFlags do
  describe "tool metadata" do
    it "has the correct tool_name" do
      expect(described_class.tool_name).to eq("manage_feature_flags")
    end

    it "has a description" do
      expect(described_class.description_value).to include("feature flags")
    end

    it "requires action in input schema" do
      schema = described_class.input_schema_value.to_h
      expect(schema[:required]).to include("action")
    end

    it "has annotations marking it as destructive" do
      expect(described_class.annotations_value.to_h[:destructiveHint]).to be true
    end
  end

  describe ".call" do
    let(:pipeline) { instance_double(Wild::AdminTools::Identity::AuthenticatedPipeline) }
    let(:server_context) { { pipeline: pipeline, caller_id: "op-1", caller_type: "user" } }

    let(:success_result) do
      Wild::AdminTools::Result.new(
        status: :success, action: "read_flag", operation: "read",
        data: { name: "beta", enabled: false }, metadata: { duration_ms: 0.3 }
      )
    end

    it "dispatches action to ToolHandler" do
      allow(pipeline).to receive(:call).and_return(success_result)

      response = described_class.call(
        action: "read_flag", flag_name: "beta", server_context: server_context
      )

      expect(response).to be_a(MCP::Tool::Response)
      expect(pipeline).to have_received(:call).with(
        "read_flag",
        { flag_name: "beta" },
        { caller_id: "op-1", caller_type: "user" },
        nonce: nil
      )
    end

    it "separates nonce from params" do
      allow(pipeline).to receive(:call).and_return(success_result)

      described_class.call(
        action: "toggle_flag", flag_name: "beta", enabled: true,
        nonce: "wnc_flag1", server_context: server_context
      )

      expect(pipeline).to have_received(:call).with(
        "toggle_flag",
        { flag_name: "beta", enabled: true },
        { caller_id: "op-1", caller_type: "user" },
        nonce: "wnc_flag1"
      )
    end
  end
end
