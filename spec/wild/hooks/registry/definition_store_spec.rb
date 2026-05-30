# frozen_string_literal: true

RSpec.describe Wild::Hooks::Registry::DefinitionStore do
  subject(:store) { described_class.new }

  let(:definition) { build_definition }

  describe '#register' do
    it 'stores a definition and returns it' do
      result = store.register(definition)
      expect(result).to be definition
    end

    it 'raises DuplicateHookError when same name is registered twice' do
      store.register(definition)
      dup = build_definition
      expect { store.register(dup) }
        .to raise_error(Wild::Hooks::DuplicateHookError, /before_tool_call/)
    end

    it 'raises ArgumentError for non-HookDefinition' do
      expect { store.register('not_a_definition') }
        .to raise_error(ArgumentError)
    end
  end

  describe '#fetch' do
    it 'returns the registered definition by name' do
      store.register(definition)
      expect(store.fetch('before_tool_call')).to be definition
    end

    it 'raises HookNotFoundError for unknown name' do
      expect { store.fetch('unknown') }
        .to raise_error(Wild::Hooks::HookNotFoundError, /unknown/)
    end
  end

  describe '#find' do
    it 'returns nil for unknown name' do
      expect(store.find('nope')).to be_nil
    end

    it 'returns definition when found' do
      store.register(definition)
      expect(store.find('before_tool_call')).to be definition
    end
  end

  describe '#registered?' do
    it 'returns false before registration' do
      expect(store.registered?('before_tool_call')).to be false
    end

    it 'returns true after registration' do
      store.register(definition)
      expect(store.registered?('before_tool_call')).to be true
    end
  end

  describe '#all' do
    it 'returns empty array when empty' do
      expect(store.all).to eq([])
    end

    it 'returns all registered definitions' do
      d2 = build_definition(name: 'after_session', trigger: :after_session)
      store.register(definition)
      store.register(d2)
      expect(store.all.size).to eq(2)
    end
  end

  describe '#deprecated / #active' do
    let(:dep) { build_deprecated_definition }

    before do
      store.register(definition)
      store.register(dep)
    end

    it '#deprecated returns only deprecated definitions' do
      expect(store.deprecated).to eq([dep])
    end

    it '#active returns only non-deprecated definitions' do
      expect(store.active).to eq([definition])
    end
  end

  describe '#by_trigger' do
    it 'returns definitions matching the trigger' do
      d2 = build_definition(name: 'also_before', trigger: :before_tool_call)
      d3 = build_definition(name: 'after_hook', trigger: :after_session)
      store.register(definition)
      store.register(d2)
      store.register(d3)
      results = store.by_trigger(:before_tool_call)
      expect(results.map(&:name)).to contain_exactly('before_tool_call', 'also_before')
    end
  end

  describe '#count / #clear!' do
    it 'returns 0 for empty store' do
      expect(store.count).to eq(0)
    end

    it 'increments on register' do
      store.register(definition)
      expect(store.count).to eq(1)
    end

    it '#clear! empties the store' do
      store.register(definition)
      store.clear!
      expect(store.count).to eq(0)
    end
  end
end
