# frozen_string_literal: true

RSpec.describe Wild::Hooks::Models::HookResult do
  let(:handler) { build_handler }

  describe '.new' do
    it 'creates a result with :success outcome' do
      r = described_class.new(handler: handler, outcome: :success, duration_ms: 5.0)
      expect(r.outcome).to eq(:success)
    end

    it 'stores duration_ms as float' do
      r = described_class.new(handler: handler, outcome: :success, duration_ms: 5)
      expect(r.duration_ms).to be_a(Float)
    end

    it 'sets executed_at' do
      before = Time.now
      r = described_class.new(handler: handler, outcome: :success, duration_ms: 1.0)
      expect(r.executed_at).to be >= before
    end

    it 'raises on invalid outcome' do
      expect { described_class.new(handler: handler, outcome: :unknown, duration_ms: 1.0) }
        .to raise_error(ArgumentError, /outcome/)
    end

    it 'stores error' do
      err = StandardError.new('oops')
      r = described_class.new(handler: handler, outcome: :error, duration_ms: 1.0, error: err)
      expect(r.error).to be err
    end

    it 'stores return_value' do
      r = described_class.new(handler: handler, outcome: :success, duration_ms: 1.0,
                              return_value: 42)
      expect(r.return_value).to eq(42)
    end
  end

  describe 'outcome predicates' do
    %i[success error timeout skipped].each do |outcome|
      it "#{outcome}? returns true for #{outcome} result" do
        r = described_class.new(handler: handler, outcome: outcome, duration_ms: 1.0)
        expect(r.public_send(:"#{outcome}?")).to be true
      end

      it "#{outcome}? returns false for other outcomes" do
        other = (%i[success error timeout skipped] - [outcome]).first
        r = described_class.new(handler: handler, outcome: other, duration_ms: 1.0)
        expect(r.public_send(:"#{outcome}?")).to be false
      end
    end
  end

  describe '#to_h' do
    it 'includes all expected keys' do
      r = build_result
      expect(r.to_h.keys).to include(:handler_id, :hook_name, :outcome, :duration_ms, :error,
                                     :return_value, :executed_at)
    end

    it 'serialises error as message string' do
      err = RuntimeError.new('fail')
      r = described_class.new(handler: handler, outcome: :error, duration_ms: 1.0, error: err)
      expect(r.to_h[:error]).to eq('fail')
    end

    it 'serialises nil error as nil' do
      r = build_result
      expect(r.to_h[:error]).to be_nil
    end
  end

  describe '#inspect' do
    it 'includes class name and outcome' do
      r = build_result
      expect(r.inspect).to include('HookResult')
      expect(r.inspect).to include('success')
    end
  end
end
