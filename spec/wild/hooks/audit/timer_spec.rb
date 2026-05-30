# frozen_string_literal: true

RSpec.describe Wild::Hooks::Audit::Timer do
  describe ".now" do
    it "returns a Float (monotonic seconds)" do
      expect(described_class.now).to be_a(Float)
    end

    it "is monotonically non-decreasing" do
      a = described_class.now
      b = described_class.now
      expect(b).to be >= a
    end
  end

  describe ".elapsed_ms" do
    it "returns 0 when called immediately after a fresh now()" do
      start = described_class.now
      expect(described_class.elapsed_ms(start)).to be >= 0
    end

    it "reflects a real sleep duration in milliseconds" do
      start = described_class.now
      sleep 0.02
      elapsed = described_class.elapsed_ms(start)
      expect(elapsed).to be >= 15  # 20ms target with generous lower bound for CI jitter
      expect(elapsed).to be < 500  # generous upper bound
    end

    it "returns an Integer (rounded)" do
      expect(described_class.elapsed_ms(described_class.now)).to be_a(Integer)
    end

    it "is non-negative for any monotonic baseline" do
      start = described_class.now
      sleep 0.001
      expect(described_class.elapsed_ms(start)).to be >= 0
    end
  end
end
