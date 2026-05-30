# frozen_string_literal: true

RSpec.describe Wild::Hooks::Execution::TimeoutGuard do
  describe "#call" do
    it "returns [:ok, return_value, duration_ms] on success" do
      guard = described_class.new(2_000)
      status, value, duration = guard.call { :hello }
      expect(status).to eq(:ok)
      expect(value).to eq(:hello)
      expect(duration).to be >= 0
    end

    it "returns [:timeout, nil, duration_ms] when timeout exceeded" do
      guard = described_class.new(50) # 50ms
      status, value, duration = guard.call { sleep 1 }
      expect(status).to eq(:timeout)
      expect(value).to be_nil
      expect(duration).to be >= 0
    end

    it "records duration in milliseconds" do
      guard = described_class.new(2_000)
      _, _, duration = guard.call { :fast }
      expect(duration).to be_a(Numeric)
      expect(duration).to be >= 0
    end

    it "propagates non-timeout errors through the block context" do
      guard = described_class.new(2_000)
      # The guard does NOT rescue standard errors — they bubble out
      expect { guard.call { raise "boom" } }.to raise_error(RuntimeError, "boom")
    end
  end
end
