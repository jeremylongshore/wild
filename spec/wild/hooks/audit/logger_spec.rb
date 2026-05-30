# frozen_string_literal: true

RSpec.describe Wild::Hooks::Audit::Logger do
  subject(:logger) { described_class.new(config: config) }

  let(:config) { Wild.config.hooks }
  let(:handler) { build_handler }
  let(:result)  { build_result(handler: handler) }

  describe '#record' do
    it 'returns a HookEvent' do
      event = logger.record(result, { tool: 'bash' })
      expect(event).to be_a(Wild::Hooks::Models::HookEvent)
    end

    it 'stores the event in the trail' do
      logger.record(result, {})
      expect(logger.trail.count).to eq(1)
    end

    it 'includes context summary in the event' do
      event = logger.record(result, { tool: 'bash', user: 'alice' })
      expect(event.context_summary).to include('tool')
      expect(event.context_summary).to include('bash')
    end

    it 'records outcome from result' do
      event = logger.record(result, {})
      expect(event.outcome).to eq(:success)
    end

    it 'records error message for error results' do
      err = RuntimeError.new('boom')
      error_result = build_result(handler: handler, outcome: :error, error: err)
      event = logger.record(error_result, {})
      expect(event.error_message).to eq('boom')
    end

    context 'when audit logging is disabled' do
      before { config.enable_audit_logging = false }

      it 'returns nil and does not store anything' do
        result = logger.record(build_result, {})
        expect(result).to be_nil
        expect(logger.trail.count).to eq(0)
      end
    end

    it 'handles empty context gracefully' do
      event = logger.record(result, {})
      expect(event.context_summary).to eq('')
    end

    it 'handles nil-handler result gracefully' do
      null_result = Wild::Hooks::Models::HookResult.new(handler: nil, outcome: :success,
                                                        duration_ms: 1.0)
      expect { logger.record(null_result, {}) }.not_to raise_error
    end
  end

  describe '#trail' do
    it 'returns a Trail instance' do
      expect(logger.trail).to be_a(Wild::Hooks::Audit::Trail)
    end
  end
end
