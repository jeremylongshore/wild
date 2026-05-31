# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Server::Tools::ManageBackgroundJobs do
  describe "tool metadata" do
    it "has the correct tool_name" do
      expect(described_class.tool_name).to eq("manage_background_jobs")
    end

    it "has a description" do
      expect(described_class.description_value).to include("background jobs")
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
        status: :success, action: "inspect_job", operation: "read",
        data: { job_id: "j1" }, metadata: { duration_ms: 1.0 }
      )
    end

    it "dispatches action to ToolHandler" do
      allow(pipeline).to receive(:call).and_return(success_result)

      response = described_class.call(action: "inspect_job", job_id: "j1", server_context: server_context)

      expect(response).to be_a(MCP::Tool::Response)
      expect(pipeline).to have_received(:call).with(
        "inspect_job",
        { job_id: "j1" },
        { caller_id: "op-1", caller_type: "user" },
        nonce: nil
      )
    end

    it "separates nonce from params" do
      allow(pipeline).to receive(:call).and_return(success_result)

      described_class.call(
        action: "retry_job", job_id: "j1", nonce: "wnc_abc",
        server_context: server_context
      )

      expect(pipeline).to have_received(:call).with(
        "retry_job",
        { job_id: "j1" },
        { caller_id: "op-1", caller_type: "user" },
        nonce: "wnc_abc"
      )
    end
  end
end
