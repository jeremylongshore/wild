# frozen_string_literal: true

RSpec.describe Wild::Hooks::Execution::ErrorIsolator do
  subject(:isolator) { described_class.new }

  describe '#call' do
    it 'returns [:ok, return_value] on success' do
      status, value = isolator.call { 42 }
      expect(status).to eq(:ok)
      expect(value).to eq(42)
    end

    it 'returns [:error, exception] on StandardError' do
      err = RuntimeError.new('oops')
      status, value = isolator.call { raise err }
      expect(status).to eq(:error)
      expect(value).to be err
    end

    it 'catches subclasses of StandardError' do
      status, value = isolator.call { raise ArgumentError, 'bad arg' }
      expect(status).to eq(:error)
      expect(value).to be_a(ArgumentError)
    end

    it 're-raises Timeout::Error' do
      require 'timeout'
      expect { isolator.call { raise Timeout::Error } }.to raise_error(Timeout::Error)
    end

    it 're-raises Interrupt' do
      expect { isolator.call { raise Interrupt } }.to raise_error(Interrupt)
    end

    it 'passes the block return value through' do
      _status, value = isolator.call { { result: 'data' } }
      expect(value).to eq({ result: 'data' })
    end
  end
end
