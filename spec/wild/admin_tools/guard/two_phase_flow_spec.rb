# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Wild::AdminTools::Guard::TwoPhaseFlow do
  subject(:two_phase) { described_class.new }

  let(:job_adapter) { Wild::AdminTools::TestSupport::TestJobAdapter.new }
  let(:policy_config) { valid_policy_config }
  let(:executor) { Wild::AdminTools::Executor::JobExecutor.new }
  let(:action_config) { policy_config.action("retry_job") }
  let(:caller_id) { "operator-1" }
  let(:job_id) { "job-abc123" }
  let(:params) { { job_id: job_id } }

  before do
    Wild::AdminTools.configure { |c| c.job_adapter = job_adapter }
    job_adapter.seed_job(job_id)
  end

  after { two_phase.nonce_manager.store.stop_sweep! }

  describe "#preview_with_nonce" do
    subject(:result) { two_phase.preview_with_nonce("retry_job", params, caller_id, executor, action_config) }

    it "returns a Result with status :preview" do
      expect(result.status).to eq(:preview)
    end

    it "embeds a nonce in metadata" do
      nonce = result.metadata[:nonce]
      expect(nonce).to be_a(String)
      expect(nonce).to start_with("wnc_")
    end

    it "sets requires_confirmation in metadata" do
      expect(result.metadata[:requires_confirmation]).to be(true)
    end

    it "includes preview data from the executor" do
      expect(result.data).to have_key(:will_retry)
    end
  end

  describe "#confirm_and_execute" do
    context "with a valid nonce" do
      let(:preview) { two_phase.preview_with_nonce("retry_job", params, caller_id, executor, action_config) }
      let(:nonce) { preview.metadata[:nonce] }

      it "returns a success Result" do
        result = two_phase.confirm_and_execute(nonce, "retry_job", params, caller_id, executor)
        expect(result.status).to eq(:success)
      end

      it "triggers the actual mutation on the adapter" do
        two_phase.confirm_and_execute(nonce, "retry_job", params, caller_id, executor)
        expect(job_adapter.write_methods_called.pluck(:method)).to include(:retry_job!)
      end
    end

    context "with an invalid nonce" do
      it "returns a denied Result" do
        result = two_phase.confirm_and_execute("wnc_bogus", "retry_job", params, caller_id, executor)
        expect(result.status).to eq(:denied)
      end

      it "includes nonce_invalid as the client reason" do
        result = two_phase.confirm_and_execute("wnc_bogus", "retry_job", params, caller_id, executor)
        expect(result.metadata[:reason]).to eq("nonce_invalid")
      end
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
