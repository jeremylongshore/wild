# frozen_string_literal: true

RSpec.describe Wild::Hooks::Models::HookEvent do
  describe '.new' do
    it 'creates a valid event' do
      e = build_event
      expect(e.hook_name).to eq('before_tool_call')
      expect(e.outcome).to eq(:success)
    end

    it 'assigns a unique id' do
      a = build_event
      b = build_event
      expect(a.id).not_to eq(b.id)
    end

    it 'sets timestamp' do
      before = Time.now
      e = build_event
      expect(e.timestamp).to be >= before
    end

    it 'coerces outcome to symbol' do
      e = described_class.new(hook_name: 'x', handler_id: 'h1', outcome: 'success',
                              duration_ms: 1.0)
      expect(e.outcome).to eq(:success)
    end

    it 'truncates long context_summary' do
      long_summary = 'a' * 300
      e = described_class.new(hook_name: 'x', handler_id: 'h1', outcome: :success,
                              duration_ms: 1.0, context_summary: long_summary)
      expect(e.context_summary.length).to be <= Wild::Hooks::Models::HookEvent::CONTEXT_SUMMARY_MAX_LENGTH
      expect(e.context_summary).to end_with('...')
    end

    it 'does not truncate short context_summary' do
      e = described_class.new(hook_name: 'x', handler_id: 'h1', outcome: :success,
                              duration_ms: 1.0, context_summary: 'short')
      expect(e.context_summary).to eq('short')
    end

    it 'stores error_message' do
      e = described_class.new(hook_name: 'x', handler_id: 'h1', outcome: :error,
                              duration_ms: 1.0, error_message: 'boom')
      expect(e.error_message).to eq('boom')
    end

    it 'stores nil error_message when not provided' do
      e = build_event
      expect(e.error_message).to be_nil
    end
  end

  describe '#to_h' do
    it 'includes all expected keys' do
      e = build_event
      expect(e.to_h.keys).to include(:id, :hook_name, :handler_id, :outcome, :duration_ms,
                                     :timestamp, :context_summary, :error_message)
    end
  end

  describe '#inspect' do
    it 'includes class name, hook_name, outcome, and timestamp' do
      e = build_event
      expect(e.inspect).to include('HookEvent')
      expect(e.inspect).to include('before_tool_call')
    end
  end
end
