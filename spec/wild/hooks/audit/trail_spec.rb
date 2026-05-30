# frozen_string_literal: true

RSpec.describe Wild::Hooks::Audit::Trail do
  subject(:trail) { described_class.new(max_entries: 5) }

  let(:event) { build_event }

  describe '#append' do
    it 'stores an event and returns it' do
      result = trail.append(event)
      expect(result).to be event
    end

    it 'increments count' do
      trail.append(event)
      expect(trail.count).to eq(1)
    end

    it 'raises ArgumentError for non-HookEvent' do
      expect { trail.append('not_an_event') }.to raise_error(ArgumentError)
    end
  end

  describe 'ring buffer behaviour' do
    it 'evicts oldest entry when max_entries exceeded' do
      events = Array.new(6) { build_event }
      events.each { |e| trail.append(e) }
      expect(trail.count).to eq(5)
    end

    it 'retains the most recent entries' do
      events = Array.new(6) { build_event }
      events.each { |e| trail.append(e) }
      expect(trail.all).not_to include(events.first)
      expect(trail.all).to include(events.last)
    end
  end

  describe '#for_hook' do
    it 'returns events matching hook_name' do
      e2 = build_event(hook_name: 'other_hook')
      trail.append(event)
      trail.append(e2)
      expect(trail.for_hook('before_tool_call')).to eq([event])
    end
  end

  describe '#by_outcome' do
    it 'returns events matching outcome' do
      e_error = build_event(outcome: :error)
      trail.append(event)
      trail.append(e_error)
      expect(trail.by_outcome(:success)).to eq([event])
      expect(trail.by_outcome(:error)).to eq([e_error])
    end
  end

  describe '#for_handler' do
    it 'returns events for a specific handler_id' do
      e2 = build_event(handler_id: 'other_handler')
      trail.append(event)
      trail.append(e2)
      result = trail.for_handler(event.handler_id)
      expect(result).to include(event)
      expect(result).not_to include(e2)
    end
  end

  describe '#in_range' do
    let(:past)   { Time.now - 100 }
    let(:future) { Time.now + 100 }

    it 'returns all events when no bounds given' do
      trail.append(event)
      expect(trail.in_range).to eq([event])
    end

    it 'filters by from boundary' do
      trail.append(event)
      expect(trail.in_range(from: future)).to be_empty
    end

    it 'filters by to boundary' do
      trail.append(event)
      expect(trail.in_range(to: past)).to be_empty
    end

    it 'returns event within range' do
      trail.append(event)
      expect(trail.in_range(from: past, to: future)).to include(event)
    end
  end

  describe '#all' do
    it 'returns empty array when empty' do
      expect(trail.all).to eq([])
    end

    it 'returns a duplicate (not the internal array)' do
      trail.append(event)
      copy = trail.all
      copy << 'extra'
      expect(trail.count).to eq(1)
    end
  end

  describe '#clear!' do
    it 'empties the trail' do
      trail.append(event)
      trail.clear!
      expect(trail.count).to eq(0)
    end
  end
end
