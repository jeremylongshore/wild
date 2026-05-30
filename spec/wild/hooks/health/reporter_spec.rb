# frozen_string_literal: true

RSpec.describe Wild::Hooks::Health::Reporter do
  subject(:reporter) { described_class.new(monitor: monitor, registry: registry) }

  let(:monitor) { Wild::Hooks::Health::Monitor.new }
  let(:handler) do
    registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {})
  end
  let(:registry) { setup_registry_with_hook }

  def record_success(hndlr = handler, duration_ms: 10.0)
    monitor.record(
      Wild::Hooks::Models::HookResult.new(handler: hndlr, outcome: :success, duration_ms: duration_ms)
    )
  end

  describe '#summary' do
    it 'returns a hash with expected keys' do
      summary = reporter.summary
      expect(summary.keys).to include(
        :total_handlers_tracked,
        :total_calls,
        :total_errors,
        :total_timeouts,
        :total_successes,
        :slow_handlers,
        :failing_handlers,
        :stale_handlers
      )
    end

    it 'counts stale handlers that have never been called' do
      handler # force creation
      summary = reporter.summary
      expect(summary[:stale_handlers]).to include(handler.id)
    end

    it 'does not include called handlers in stale list' do
      record_success
      summary = reporter.summary
      expect(summary[:stale_handlers]).not_to include(handler.id)
    end

    it 'sums calls correctly' do
      record_success
      record_success
      expect(reporter.summary[:total_calls]).to eq(2)
    end
  end

  describe '#detailed' do
    it 'returns an array of metric hashes' do
      record_success
      detailed = reporter.detailed
      expect(detailed).to be_an(Array)
      expect(detailed.first).to be_a(Hash)
    end
  end

  describe '#for_handler' do
    it 'returns nil for unknown handler' do
      expect(reporter.for_handler('nonexistent')).to be_nil
    end

    it 'returns a metric hash for a known handler' do
      record_success
      result = reporter.for_handler(handler.id)
      expect(result[:handler_id]).to eq(handler.id)
    end
  end
end
