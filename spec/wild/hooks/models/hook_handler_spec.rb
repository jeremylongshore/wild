# frozen_string_literal: true

RSpec.describe Wild::Hooks::Models::HookHandler do
  describe ".new" do
    it "creates a valid handler" do
      h = described_class.new(hook_name: "before_tool_call", callable: ->(_) {})
      expect(h.hook_name).to eq("before_tool_call")
    end

    it "defaults priority to 100" do
      h = build_handler
      expect(h.priority).to eq(100)
    end

    it "defaults enabled to true" do
      h = build_handler
      expect(h).to be_enabled
    end

    it "defaults timeout_ms to nil" do
      h = build_handler
      expect(h.timeout_ms).to be_nil
    end

    it "freezes metadata" do
      h = build_handler(metadata: { source: "test" })
      expect(h.metadata).to be_frozen
    end

    it "assigns a unique id" do
      a = build_handler
      b = build_handler
      expect(a.id).not_to eq(b.id)
    end

    it "sets registered_at" do
      before = Time.now.utc
      h = build_handler
      expect(h.registered_at).to be >= before
    end

    it "raises InvalidHandlerError when callable does not respond to #call" do
      expect { described_class.new(hook_name: "x", callable: "not_callable") }
        .to raise_error(Wild::Hooks::InvalidHandlerError)
    end

    it "raises on blank hook_name" do
      expect { described_class.new(hook_name: "", callable: ->(_) {}) }
        .to raise_error(ArgumentError, /hook_name/)
    end

    it "raises on non-integer priority" do
      expect { described_class.new(hook_name: "x", callable: ->(_) {}, priority: "1") }
        .to raise_error(ArgumentError, /priority/)
    end

    it "raises on non-positive timeout_ms" do
      expect { described_class.new(hook_name: "x", callable: ->(_) {}, timeout_ms: 0) }
        .to raise_error(ArgumentError, /timeout_ms/)
    end

    it "accepts an object responding to #call" do
      obj = Class.new { def call(_ctx) = :ok }.new
      expect { described_class.new(hook_name: "x", callable: obj) }.not_to raise_error
    end
  end

  describe "#call" do
    it "delegates to the callable" do
      h = build_handler(callable: ->(ctx) { ctx[:val] * 2 })
      expect(h.call({ val: 5 })).to eq(10)
    end
  end

  describe "#enable! / #disable!" do
    it "enables a disabled handler" do
      h = build_handler(enabled: false)
      h.enable!
      expect(h).to be_enabled
    end

    it "disables an enabled handler" do
      h = build_handler
      h.disable!
      expect(h).not_to be_enabled
    end

    it "returns self for chaining" do
      h = build_handler
      expect(h.disable!).to be h
      expect(h.enable!).to be h
    end
  end

  describe "#to_h" do
    it "includes all relevant fields" do
      h = build_handler
      expect(h.to_h.keys).to include(:id, :hook_name, :priority, :timeout_ms, :enabled, :metadata,
                                     :registered_at)
    end
  end

  describe "#inspect" do
    it "includes class name, id, hook_name, priority, enabled" do
      h = build_handler
      expect(h.inspect).to include("HookHandler")
      expect(h.inspect).to include("before_tool_call")
    end
  end
end
