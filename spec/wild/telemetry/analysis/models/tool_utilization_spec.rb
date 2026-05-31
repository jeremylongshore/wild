# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::ToolUtilization do
  subject(:util) { build_tool_utilization }

  describe "attribute readers" do
    it "exposes action" do
      expect(util.action).to eq("read_file")
    end

    it "exposes invocation_count" do
      expect(util.invocation_count).to eq(20)
    end

    it "exposes unique_callers" do
      expect(util.unique_callers).to eq(3)
    end

    it "exposes success_rate" do
      expect(util.success_rate).to eq(0.9)
    end

    it "exposes avg_duration_ms" do
      expect(util.avg_duration_ms).to eq(45.0)
    end

    it "defaults invocation_count to 0" do
      expect(build_tool_utilization("invocation_count" => nil).invocation_count).to eq(0)
    end

    it "defaults success_rate to 0.0" do
      expect(build_tool_utilization("success_rate" => nil).success_rate).to eq(0.0)
    end
  end

  describe "record_type" do
    it "is tool_utilization" do
      expect(util.record_type).to eq("tool_utilization")
    end
  end
end
