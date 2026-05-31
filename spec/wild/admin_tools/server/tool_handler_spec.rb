# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Server::ToolHandler do
  let(:pipeline) { instance_double(Wild::AdminTools::Identity::AuthenticatedPipeline) }
  let(:server_context) { { pipeline: pipeline, caller_id: "op-1", caller_type: "user" } }

  let(:success_result) do
    Wild::AdminTools::Result.new(
      status: :success, action: "inspect_job", operation: "read",
      data: { job_id: "j1" }, metadata: { duration_ms: 1.0 }
    )
  end

  describe ".execute" do
    it "dispatches to the pipeline and formats the response" do
      allow(pipeline).to receive(:call).and_return(success_result)

      response = described_class.execute(
        action_name: "inspect_job",
        params: { job_id: "j1" },
        server_context: server_context
      )

      expect(response).to be_a(MCP::Tool::Response)
      expect(response.error?).to be false
      expect(pipeline).to have_received(:call).with(
        "inspect_job",
        { job_id: "j1" },
        { caller_id: "op-1", caller_type: "user" },
        nonce: nil
      )
    end

    it "passes nonce through to the pipeline" do
      allow(pipeline).to receive(:call).and_return(success_result)

      described_class.execute(
        action_name: "retry_job",
        params: { job_id: "j1" },
        server_context: server_context,
        nonce: "wnc_test123"
      )

      expect(pipeline).to have_received(:call).with(
        "retry_job",
        { job_id: "j1" },
        { caller_id: "op-1", caller_type: "user" },
        nonce: "wnc_test123"
      )
    end

    it "catches StandardError and returns an error response" do
      allow(pipeline).to receive(:call).and_raise(StandardError, "boom")

      response = described_class.execute(
        action_name: "inspect_job",
        params: {},
        server_context: server_context
      )

      expect(response.error?).to be true
      expect(response.structured_content[:message]).to eq("boom")
    end

    it "catches Wild::AdminTools::Error and returns an error response" do
      allow(pipeline).to receive(:call).and_raise(Wild::AdminTools::AdapterError, "adapter down")

      response = described_class.execute(
        action_name: "inspect_job",
        params: {},
        server_context: server_context
      )

      expect(response.error?).to be true
      expect(response.structured_content[:message]).to eq("adapter down")
    end

    it "raises ConfigurationError when pipeline is missing from server_context" do
      response = described_class.execute(
        action_name: "inspect_job",
        params: {},
        server_context: { caller_id: "op-1" }
      )

      expect(response.error?).to be true
      expect(response.structured_content[:status]).to eq("error")
    end
  end
end
