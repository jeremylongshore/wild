# frozen_string_literal: true

RSpec.describe Wild::Hooks::Registry::HookRegistry do
  subject(:registry) { described_class.new }

  describe '#define' do
    it 'registers a hook definition and returns it' do
      d = registry.define(name: 'before_tool_call', trigger: :before_tool_call)
      expect(d).to be_a(Wild::Hooks::Models::HookDefinition)
      expect(d.name).to eq('before_tool_call')
    end

    it 'raises DuplicateHookError for duplicate names' do
      registry.define(name: 'x', trigger: :on_error)
      expect { registry.define(name: 'x', trigger: :on_error) }
        .to raise_error(Wild::Hooks::DuplicateHookError)
    end
  end

  describe '#register_handler' do
    before { registry.define(name: 'before_tool_call', trigger: :before_tool_call) }

    it 'registers a handler and returns it' do
      h = registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {})
      expect(h).to be_a(Wild::Hooks::Models::HookHandler)
    end

    it 'raises HookNotFoundError when definition not present' do
      expect { registry.register_handler(hook_name: 'missing', callable: ->(_) {}) }
        .to raise_error(Wild::Hooks::HookNotFoundError)
    end
  end

  describe '#handlers_for' do
    before do
      registry.define(name: 'before_tool_call', trigger: :before_tool_call)
      registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {}, priority: 200)
      registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {}, priority: 10)
      registry.register_handler(hook_name: 'before_tool_call', callable: ->(_) {}, priority: 100)
    end

    it 'returns enabled handlers sorted by priority ascending' do
      handlers = registry.handlers_for('before_tool_call')
      expect(handlers.map(&:priority)).to eq([10, 100, 200])
    end

    it 'excludes disabled handlers' do
      registry.handler_store.enabled_for_hook('before_tool_call').first.disable!
      handlers = registry.handlers_for('before_tool_call')
      expect(handlers.size).to eq(2)
    end
  end

  describe '#definition_for' do
    it 'returns the definition' do
      registry.define(name: 'x', trigger: :on_error)
      d = registry.definition_for('x')
      expect(d.name).to eq('x')
    end

    it 'raises HookNotFoundError for unknown hook' do
      expect { registry.definition_for('nope') }
        .to raise_error(Wild::Hooks::HookNotFoundError)
    end
  end

  describe '#hook_defined?' do
    it 'returns false before definition' do
      expect(registry.hook_defined?('x')).to be false
    end

    it 'returns true after definition' do
      registry.define(name: 'x', trigger: :on_error)
      expect(registry.hook_defined?('x')).to be true
    end
  end

  describe '#all_definitions / #all_handlers' do
    it 'returns all definitions' do
      registry.define(name: 'a', trigger: :on_error)
      registry.define(name: 'b', trigger: :before_session)
      expect(registry.all_definitions.size).to eq(2)
    end

    it 'returns all handlers' do
      registry.define(name: 'a', trigger: :on_error)
      registry.register_handler(hook_name: 'a', callable: ->(_) {})
      registry.register_handler(hook_name: 'a', callable: ->(_) {})
      expect(registry.all_handlers.size).to eq(2)
    end
  end

  describe '#clear!' do
    it 'removes all definitions and handlers' do
      registry.define(name: 'x', trigger: :on_error)
      registry.register_handler(hook_name: 'x', callable: ->(_) {})
      registry.clear!
      expect(registry.all_definitions).to be_empty
      expect(registry.all_handlers).to be_empty
    end
  end
end
