# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers

RSpec.describe "Gate failure modes — adversarial safety" do
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
      pipeline: pipeline, caller_id: "gate-tester"
    )
  end

  before do
    Wild::AdminTools.configure do |c|
      c.job_adapter = job_adapter
      c.cache_adapter = cache_adapter
      c.flag_adapter = flag_adapter
    end
    job_adapter.seed_job("job-1")
  end

  after { nonce_store.stop_sweep! }

  context "when gate explicitly denies" do
    before { gate.default_result = false }

    it "returns denied with gate_denied and produces an audit record" do
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("gate_denied")
      expect(audit_store.count).to be >= 1
    end
  end

  context "when gate raises GateError (simulating timeout/unreachable)" do
    before do
      allow(gate).to receive(:evaluate)
        .and_raise(Wild::AdminTools::GateError.new("gate timeout"))
    end

    it "fails closed with gate_denied and produces an audit record" do
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("gate_denied")
      expect(audit_store.count).to be >= 1
    end
  end

  context "when gate raises unexpected StandardError" do
    before do
      allow(gate).to receive(:evaluate)
        .and_raise(StandardError.new("unexpected failure"))
    end

    it "fails closed with gate_denied and produces an audit record" do
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: server_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("gate_denied")
      expect(audit_store.count).to be >= 1
    end
  end

  context "with anonymous caller (nil caller_id)" do
    let(:anon_context) do
      Wild::AdminTools::Server::ServerFactory.build_server_context(
        pipeline: pipeline, caller_id: nil
      )
    end

    it "returns denied with anonymous_request_rejected and audit record" do
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: anon_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("anonymous_request_rejected")
      expect(audit_store.count).to be >= 1
    end
  end

  context "with empty string caller_id" do
    let(:empty_context) do
      Wild::AdminTools::Server::ServerFactory.build_server_context(
        pipeline: pipeline, caller_id: ""
      )
    end

    it "returns denied with anonymous_request_rejected and audit record" do
      response = tools::ManageBackgroundJobs.call(
        action: "inspect_job", job_id: "job-1", server_context: empty_context
      )
      body = response.structured_content
      expect(body[:status]).to eq("denied")
      expect(body[:reason]).to eq("anonymous_request_rejected")
      expect(audit_store.count).to be >= 1
    end
  end

  it "denial responses are uniform (no information leakage about gate internals)" do
    gate.default_result = false
    denied_response = tools::ManageBackgroundJobs.call(
      action: "inspect_job", job_id: "job-1", server_context: server_context
    )
    anon_context = Wild::AdminTools::Server::ServerFactory.build_server_context(
      pipeline: pipeline, caller_id: nil
    )
    anon_response = tools::ManageBackgroundJobs.call(
      action: "inspect_job", job_id: "job-1", server_context: anon_context
    )
    denied_keys = denied_response.structured_content.keys.sort
    anon_keys = anon_response.structured_content.keys.sort
    expect(denied_keys).to eq(anon_keys)
  end
end

# rubocop:enable RSpec/DescribeClass, RSpec/MultipleMemoizedHelpers
