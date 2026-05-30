# frozen_string_literal: true

RSpec.describe Wild::Hooks::Lifecycle::Manager do
  subject(:manager) { described_class.new(registry: registry, version_tracker: tracker) }

  let(:registry) { setup_registry_with_hook }
  let!(:handler) do
    registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {})
  end
  let(:tracker) { Wild::Hooks::Lifecycle::VersionTracker.new }

  describe '#enable_handler / #disable_handler' do
    it 'disables an enabled handler by id' do
      manager.disable_handler(handler.id)
      expect(handler).not_to be_enabled
    end

    it 'enables a disabled handler by id' do
      handler.disable!
      manager.enable_handler(handler.id)
      expect(handler).to be_enabled
    end

    it 'raises when handler id not found' do
      expect { manager.enable_handler('nonexistent_id') }
        .to raise_error(Wild::Hooks::Error, /Handler not found/)
    end
  end

  describe '#enable_all_for / #disable_all_for' do
    let!(:handler2) do
      registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {}, priority: 200)
    end

    it 'disables all handlers for a hook' do
      manager.disable_all_for('before_tool_call')
      expect(handler).not_to be_enabled
      expect(handler2).not_to be_enabled
    end

    it 'enables all handlers for a hook' do
      handler.disable!
      handler2.disable!
      manager.enable_all_for('before_tool_call')
      expect(handler).to be_enabled
      expect(handler2).to be_enabled
    end

    it 'raises HookNotFoundError for unknown hook' do
      expect { manager.enable_all_for('nonexistent') }
        .to raise_error(Wild::Hooks::HookNotFoundError)
    end
  end

  describe '#deprecate_hook' do
    it 'marks the hook as deprecated' do
      manager.deprecate_hook('before_tool_call')
      expect(registry.definition_for('before_tool_call')).to be_deprecated
    end

    it 'records in version tracker' do
      manager.deprecate_hook('before_tool_call')
      expect(tracker.history_for('before_tool_call').size).to eq(1)
    end

    it 'raises for unknown hook' do
      expect { manager.deprecate_hook('nope') }
        .to raise_error(Wild::Hooks::HookNotFoundError)
    end
  end

  describe '#update_version' do
    it 'updates the hook definition version' do
      manager.update_version('before_tool_call', '2.0.0')
      expect(registry.definition_for('before_tool_call').version).to eq('2.0.0')
    end

    it 'records in version tracker' do
      manager.update_version('before_tool_call', '2.0.0')
      expect(tracker.current_version('before_tool_call')).to eq('2.0.0')
    end
  end

  describe '#version_history_for' do
    it 'delegates to version tracker' do
      tracker.record('before_tool_call', '1.0.0')
      expect(manager.version_history_for('before_tool_call').size).to eq(1)
    end
  end
end
