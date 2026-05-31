# frozen_string_literal: true

module Wild
  module AdminTools
    module Server
      module ServerFactory
        TOOLS = [
          Tools::ManageBackgroundJobs,
          Tools::ManageCache,
          Tools::ManageFeatureFlags
        ].freeze

        def self.create(server_context: {})
          MCP::Server.new(
            name: "wild-admin-tools-mcp",
            version: VERSION,
            tools: TOOLS,
            server_context: server_context
          )
        end

        def self.build_pipeline(gate:, policy_config:, audit_store: nil)
          guard_pipeline = Guard::Pipeline.new(policy_config: policy_config)
          recorder = Audit::Recorder.new(store: audit_store || Audit::MemoryStore.new)
          audited_pipeline = Audit::AuditedPipeline.new(pipeline: guard_pipeline, recorder: recorder)
          gate_client = Identity::GateClient.new(gate: gate)
          authenticated_pipeline = Identity::AuthenticatedPipeline.new(
            audited_pipeline: audited_pipeline,
            gate_client: gate_client
          )

          authenticated_pipeline.register_executor(Executor::JobExecutor.new)
          authenticated_pipeline.register_executor(Executor::CacheExecutor.new)
          authenticated_pipeline.register_executor(Executor::FlagExecutor.new)

          authenticated_pipeline
        end

        def self.build_server_context(pipeline:, caller_id:, caller_type: "user")
          { pipeline: pipeline, caller_id: caller_id, caller_type: caller_type }
        end
      end
    end
  end
end
