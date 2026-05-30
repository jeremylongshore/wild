# frozen_string_literal: true

RSpec.describe Wild::Hooks::Health::Monitor do
  subject(:monitor) { described_class.new }

  let(:handler) { build_handler }

  def make_result(outcome:, duration_ms: 10.0, handler: nil)
    h = handler || build_handler
    Wild::Hooks::Models::HookResult.new(
      handler: h,
      outcome: outcome,
      duration_ms: duration_ms
    )
  end

  describe "#record" do
    it "creates metrics for a new handler" do
      result = make_result(outcome: :success)
      monitor.record(result)
      expect(monitor.metrics_for(result.handler.id)).not_to be_nil
    end

    it "increments call_count" do
      result = make_result(outcome: :success, handler: handler)
      monitor.record(result)
      monitor.record(result)
      expect(monitor.metrics_for(handler.id).call_count).to eq(2)
    end

    it "increments success_count for :success" do
      result = make_result(outcome: :success, handler: handler)
      monitor.record(result)
      expect(monitor.metrics_for(handler.id).success_count).to eq(1)
    end

    it "increments error_count for :error" do
      result = make_result(outcome: :error, handler: handler)
      monitor.record(result)
      expect(monitor.metrics_for(handler.id).error_count).to eq(1)
    end

    it "increments timeout_count for :timeout" do
      result = make_result(outcome: :timeout, handler: handler)
      monitor.record(result)
      expect(monitor.metrics_for(handler.id).timeout_count).to eq(1)
    end

    it "ignores results without a handler" do
      result = Wild::Hooks::Models::HookResult.new(handler: nil, outcome: :success,
                                                   duration_ms: 1.0)
      expect { monitor.record(result) }.not_to raise_error
      expect(monitor.all_metrics).to be_empty
    end

    it "accumulates total_duration_ms" do
      r1 = make_result(outcome: :success, duration_ms: 5.0, handler: handler)
      r2 = make_result(outcome: :success, duration_ms: 10.0, handler: handler)
      monitor.record(r1)
      monitor.record(r2)
      expect(monitor.metrics_for(handler.id).total_duration_ms).to eq(15.0)
    end
  end

  describe "Metrics calculated fields" do
    let(:metrics) do
      monitor.record(make_result(outcome: :success, duration_ms: 100.0, handler: handler))
      monitor.record(make_result(outcome: :error, duration_ms: 200.0, handler: handler))
      monitor.metrics_for(handler.id)
    end

    it "calculates avg_duration_ms" do
      expect(metrics.avg_duration_ms).to eq(150.0)
    end

    it "calculates error_rate" do
      expect(metrics.error_rate).to eq(0.5)
    end

    it "calculates success_rate" do
      expect(metrics.success_rate).to eq(0.5)
    end

    it "#to_h includes all keys" do
      expect(metrics.to_h.keys).to include(
        :handler_id, :hook_name, :call_count, :success_count,
        :error_count, :timeout_count, :avg_duration_ms, :error_rate, :success_rate
      )
    end
  end

  describe "#slow_handlers" do
    it "returns handlers with avg_duration above threshold" do
      r = make_result(outcome: :success, duration_ms: 2_000.0, handler: handler)
      monitor.record(r)
      slow = monitor.slow_handlers(threshold_ms: 1_000.0)
      expect(slow.map(&:handler_id)).to include(handler.id)
    end

    it "excludes handlers below threshold" do
      r = make_result(outcome: :success, duration_ms: 10.0, handler: handler)
      monitor.record(r)
      expect(monitor.slow_handlers(threshold_ms: 1_000.0)).to be_empty
    end
  end

  describe "#failing_handlers" do
    it "returns handlers above error rate threshold" do
      3.times { monitor.record(make_result(outcome: :error, handler: handler)) }
      monitor.record(make_result(outcome: :success, handler: handler))
      failing = monitor.failing_handlers(threshold: 0.5)
      expect(failing.map(&:handler_id)).to include(handler.id)
    end

    it "excludes handlers below error rate threshold" do
      monitor.record(make_result(outcome: :success, handler: handler))
      expect(monitor.failing_handlers(threshold: 0.5)).to be_empty
    end
  end

  describe "#stale_handlers" do
    it "returns handler ids that have not been called" do
      stale = monitor.stale_handlers([handler.id])
      expect(stale).to include(handler.id)
    end

    it "excludes handler ids that have been called" do
      monitor.record(make_result(outcome: :success, handler: handler))
      stale = monitor.stale_handlers([handler.id])
      expect(stale).not_to include(handler.id)
    end
  end

  describe "#all_metrics" do
    it "returns all handler metrics" do
      h2 = build_handler(hook_name: "after_session")
      monitor.record(make_result(outcome: :success, handler: handler))
      monitor.record(make_result(outcome: :success, handler: h2))
      expect(monitor.all_metrics.size).to eq(2)
    end
  end

  describe "#clear!" do
    it "removes all metrics" do
      monitor.record(make_result(outcome: :success, handler: handler))
      monitor.clear!
      expect(monitor.all_metrics).to be_empty
    end
  end
end
