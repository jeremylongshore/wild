# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Server::ServerFactory do
  describe ".create" do
    it "returns an MCP::Server with 3 tools" do
      server = described_class.create
      expect(server).to be_a(MCP::Server)
      expect(server.tools.size).to eq(3)
    end

    it "includes all three tool names" do
      server = described_class.create
      tool_names = server.tools.keys
      expect(tool_names).to contain_exactly("manage_background_jobs", "manage_cache", "manage_feature_flags")
    end

    it "sets the server name and version" do
      server = described_class.create
      expect(server.name).to eq("wild-admin-tools-mcp")
      expect(server.version).to eq(Wild::VERSION)
    end

    it "passes server_context through" do
      ctx = { pipeline: :fake, caller_id: "x" }
      server = described_class.create(server_context: ctx)
      expect(server.server_context).to eq(ctx)
    end
  end

  describe ".build_pipeline" do
    let(:gate) { Wild::AdminTools::TestSupport::TestGate.new }

    before do
      Wild::AdminTools.configure do |c|
        c.job_adapter = Wild::AdminTools::TestSupport::TestJobAdapter.new
        c.cache_adapter = Wild::AdminTools::TestSupport::TestCacheAdapter.new
        c.flag_adapter = Wild::AdminTools::TestSupport::TestFlagAdapter.new
      end
    end

    it "returns an AuthenticatedPipeline" do
      pipeline = described_class.build_pipeline(gate: gate, policy_config: valid_policy_config)
      expect(pipeline).to be_a(Wild::AdminTools::Identity::AuthenticatedPipeline)
    end

    it "wires executors that handle known actions" do
      pipeline = described_class.build_pipeline(gate: gate, policy_config: valid_policy_config)
      result = pipeline.call("inspect_job", { job_id: "test" }, { caller_id: "op-1" })
      expect(result.status).to eq(:success)
    end
  end

  describe ".build_server_context" do
    it "returns a hash with pipeline, caller_id, and caller_type" do
      ctx = described_class.build_server_context(pipeline: :p, caller_id: "u1")
      expect(ctx).to eq({ pipeline: :p, caller_id: "u1", caller_type: "user" })
    end

    it "allows overriding caller_type" do
      ctx = described_class.build_server_context(pipeline: :p, caller_id: "u1", caller_type: "service")
      expect(ctx[:caller_type]).to eq("service")
    end
  end
end
