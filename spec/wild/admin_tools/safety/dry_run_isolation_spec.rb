# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

RSpec.describe "Dry-run isolation — adversarial safety" do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:cache_adapter) { Wild::AdminTools::TestSupport::TestCacheAdapter.new }
  let(:flag_adapter) { Wild::AdminTools::TestSupport::TestFlagAdapter.new }
  let(:gate) { Wild::AdminTools::TestSupport::TestGate.new }
  let(:audit_store) { Wild::AdminTools::Audit::MemoryStore.new }

  let(:pipeline) do
    Wild::AdminTools::Server::ServerFactory.build_pipeline(
      gate: gate, policy_config: full_policy_config, audit_store: audit_store
    )
  end

  let(:server_context) do
    Wild::AdminTools::Server::ServerFactory.build_server_context(
      pipeline: pipeline, caller_id: "adversarial-tester"
    )
  end

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
    job_adapter.seed_job("job-1", queue: "default")
    cache_adapter.seed_key("cache:1", "cached_value")
    flag_adapter.seed_flag("test_flag")
  end

  after { nonce_store.stop_sweep! }

  Wild::AdminTools::TestSupport::SafetyHelpers::MUTATION_ACTIONS.each do |tool_name, action, params|
    it "#{action}: returns preview with nonce and zero writes" do
      response = resolve_tool(tool_name).call(
        action: action, server_context: server_context, **params
      )
      body = response.structured_content
      expect(body[:status]).to eq("preview")
      expect(body[:metadata][:nonce]).to start_with("wnc_")
      expect(all_write_calls).to be_empty
    end
  end

  it "adapter state is unchanged after previewing all mutations" do
    Wild::AdminTools::TestSupport::SafetyHelpers::MUTATION_ACTIONS.each do |tool_name, action, params|
      resolve_tool(tool_name).call(action: action, server_context: server_context, **params)
    end
    expect(job_adapter.find_job("job-1")[:status]).to eq("dead")
    expect(cache_adapter.read_key("cache:1")[:exists]).to be true
    expect(flag_adapter.read_flag("test_flag")[:enabled]).to be false
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
