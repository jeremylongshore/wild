# frozen_string_literal: true

RSpec.describe Wild::Hooks::Models::HookDefinition do
  describe ".new" do
    it "creates a valid definition with required attributes" do
      d = described_class.new(name: "my_hook", trigger: :before_tool_call)
      expect(d.name).to eq("my_hook")
      expect(d.trigger).to eq(:before_tool_call)
    end

    it "sets sensible defaults" do
      d = described_class.new(name: "x", trigger: :on_error)
      expect(d.description).to eq("")
      expect(d.required_permissions).to eq([])
      expect(d.version).to eq("1.0.0")
      expect(d.deprecated).to be false
    end

    it "sets registered_at to current time" do
      before = Time.now.utc
      d = described_class.new(name: "x", trigger: :on_error)
      expect(d.registered_at).to be >= before
    end

    it "freezes required_permissions" do
      d = described_class.new(name: "x", trigger: :on_error, required_permissions: ["read"])
      expect(d.required_permissions).to be_frozen
    end

    it "coerces required_permissions to strings" do
      d = described_class.new(name: "x", trigger: :on_error, required_permissions: [:admin])
      expect(d.required_permissions).to eq(["admin"])
    end

    it "raises on blank name" do
      expect { described_class.new(name: "  ", trigger: :on_error) }
        .to raise_error(ArgumentError, /name/)
    end

    it "raises on non-string name" do
      expect { described_class.new(name: 42, trigger: :on_error) }
        .to raise_error(ArgumentError, /name/)
    end

    it "raises on non-symbol trigger" do
      expect { described_class.new(name: "x", trigger: "before") }
        .to raise_error(ArgumentError, /trigger/)
    end

    it "stores deprecated=true" do
      d = described_class.new(name: "x", trigger: :on_error, deprecated: true)
      expect(d.deprecated?).to be true
    end
  end

  describe "#==" do
    it "is equal to another definition with the same name" do
      a = described_class.new(name: "hook", trigger: :on_error)
      b = described_class.new(name: "hook", trigger: :before_session)
      expect(a).to eq(b)
    end

    it "is not equal to a definition with a different name" do
      a = described_class.new(name: "hook_a", trigger: :on_error)
      b = described_class.new(name: "hook_b", trigger: :on_error)
      expect(a).not_to eq(b)
    end
  end

  describe "#to_h" do
    it "returns a hash with all attributes" do
      d = build_definition
      h = d.to_h
      expect(h.keys).to include(:name, :trigger, :description, :required_permissions, :version,
                                :deprecated, :registered_at)
    end
  end

  describe "#inspect" do
    it "includes class name, name, trigger, version, deprecated" do
      d = build_definition
      expect(d.inspect).to include("HookDefinition")
      expect(d.inspect).to include("before_tool_call")
    end
  end
end
