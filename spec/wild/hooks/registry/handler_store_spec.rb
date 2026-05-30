# frozen_string_literal: true

RSpec.describe Wild::Hooks::Registry::HandlerStore do
  subject(:store) { described_class.new(max_per_hook: 3) }

  let(:handler) { build_handler }

  describe '#register' do
    it 'stores and returns the handler' do
      result = store.register(handler)
      expect(result).to be handler
    end

    it 'raises HandlerLimitExceededError when limit is reached' do
      3.times { store.register(build_handler) }
      expect { store.register(build_handler) }
        .to raise_error(Wild::Hooks::HandlerLimitExceededError, /before_tool_call/)
    end

    it 'raises ArgumentError for non-HookHandler' do
      expect { store.register('not_a_handler') }
        .to raise_error(ArgumentError)
    end
  end

  describe '#for_hook' do
    it 'returns empty array for unknown hook' do
      expect(store.for_hook('unknown')).to eq([])
    end

    it 'returns all handlers for the hook' do
      h2 = build_handler(priority: 50)
      store.register(handler)
      store.register(h2)
      expect(store.for_hook('before_tool_call').size).to eq(2)
    end
  end

  describe '#enabled_for_hook' do
    it 'returns only enabled handlers' do
      enabled  = build_handler(enabled: true)
      disabled = build_handler(enabled: false)
      store.register(enabled)
      store.register(disabled)
      result = store.enabled_for_hook('before_tool_call')
      expect(result).to contain_exactly(enabled)
    end
  end

  describe '#find_by_id' do
    it 'returns nil when handler not found' do
      expect(store.find_by_id('nonexistent')).to be_nil
    end

    it 'finds handler by id' do
      store.register(handler)
      expect(store.find_by_id(handler.id)).to be handler
    end
  end

  describe '#all' do
    it 'returns all handlers across hooks' do
      h2 = build_handler(hook_name: 'after_session')
      store.register(handler)
      store.register(h2)
      expect(store.all.size).to eq(2)
    end
  end

  describe '#count_for / #total_count' do
    it 'counts handlers per hook' do
      store.register(handler)
      store.register(build_handler(priority: 50))
      expect(store.count_for('before_tool_call')).to eq(2)
    end

    it 'returns total across all hooks' do
      h2 = build_handler(hook_name: 'after_session')
      store.register(handler)
      store.register(h2)
      expect(store.total_count).to eq(2)
    end
  end

  describe '#hook_names' do
    it 'returns hook names that have registered handlers' do
      h2 = build_handler(hook_name: 'after_session')
      store.register(handler)
      store.register(h2)
      expect(store.hook_names).to contain_exactly('before_tool_call', 'after_session')
    end
  end

  describe '#clear!' do
    it 'removes all handlers' do
      store.register(handler)
      store.clear!
      expect(store.total_count).to eq(0)
    end
  end
end
