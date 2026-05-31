# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

RSpec.describe "Parameter injection — adversarial safety" do
  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:tools) { Wild::AdminTools::Server::Tools }
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
      pipeline: pipeline, caller_id: "injection-tester"
    )
  end

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
  end

  after { nonce_store.stop_sweep! }

  # SQL injection via job_id
  {
    "SQL injection" => "'; DROP TABLE jobs; --",
    "shell injection" => "$(rm -rf /)",
    "Ruby interpolation injection" => "\#{system('whoami')}",
    "path traversal" => "../../etc/passwd",
    "null byte injection" => "job-1\x00admin"
  }.each do |attack_name, payload|
    it "rejects #{attack_name} in job_id" do
      response = tools::ManageBackgroundJobs.call(
        action: "retry_job", job_id: payload, server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("parameter_validation_failed")
      expect(job_adapter.write_methods_called).to be_empty
    end
  end

  # Constantize attack via flag_name
  it "rejects constantize attempt in flag_name" do
    response = tools::ManageFeatureFlags.call(
      action: "toggle_flag",
      flag_name: "Object.const_get('Kernel')",
      enabled: true,
      server_context: server_context
    )
    body = response.structured_content
    expect(body[:status]).to eq("denied")
    expect(body[:reason]).to eq("parameter_validation_failed")
    expect(flag_adapter.write_methods_called).to be_empty
  end

  # Oversized cache_key (exceeds max_length 512)
  it "rejects a cache_key exceeding max_length" do
    response = tools::ManageCache.call(
      action: "invalidate_cache_key",
      cache_key: "x" * 513,
      server_context: server_context
    )
    body = response.structured_content
    expect(body[:status]).to eq("denied")
    expect(body[:reason]).to eq("parameter_validation_failed")
    expect(cache_adapter.write_methods_called).to be_empty
  end

  # eval-style attack via flag_name
  it "rejects eval-style payload in flag_name" do
    response = tools::ManageFeatureFlags.call(
      action: "delete_flag",
      flag_name: 'eval("exit")',
      server_context: server_context
    )
    body = response.structured_content
    expect(body[:status]).to eq("denied")
    expect(body[:reason]).to eq("parameter_validation_failed")
  end

  it "no adapter methods called across all injection attempts" do
    payloads = [
      lambda {
        tools::ManageBackgroundJobs.call(action: "retry_job", job_id: "'; DROP TABLE--", server_context: server_context)
      },
      lambda {
        tools::ManageFeatureFlags.call(action: "toggle_flag", flag_name: "__send__(:system)", enabled: true,
                                       server_context: server_context)
      },
      lambda {
        tools::ManageCache.call(action: "invalidate_cache_key", cache_key: "x" * 513, server_context: server_context)
      }
    ]
    payloads.each(&:call)
    expect(all_write_calls).to be_empty
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
