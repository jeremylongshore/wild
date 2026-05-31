# frozen_string_literal: true

RSpec.shared_examples "a safe preview" do |action_name, params|
  it "never calls adapter write methods during preview" do
    result = executor.preview(action_name, params)
    expect(result.preview?).to be true

    write_calls = adapter.write_methods_called
    expect(write_calls).to be_empty,
                           "Preview for '#{action_name}' called write methods: #{write_calls.pluck(:method)}"
  end
end

RSpec.shared_examples "an executor action" do |action_name, operation, params|
  describe "action: #{action_name}" do
    it "returns a preview Result" do
      result = executor.preview(action_name, params)
      expect(result).to be_a(Wild::AdminTools::Result)
      expect(result.status).to eq(:preview)
      expect(result.action).to eq(action_name)
      expect(result.operation).to eq(operation)
      expect(result.metadata).to include(:duration_ms)
    end

    it "returns nil snapshots on preview" do
      result = executor.preview(action_name, params)
      expect(result.before_snapshot).to be_nil
      expect(result.after_snapshot).to be_nil
    end

    it_behaves_like "a safe preview", action_name, params
  end
end

RSpec.shared_examples "a read action" do |action_name, params|
  it_behaves_like "an executor action", action_name, "read", params

  describe "execute: #{action_name}" do
    it "returns a success Result for read operations" do
      result = executor.execute(action_name, params)
      expect(result).to be_a(Wild::AdminTools::Result)
      expect(result.status).to eq(:success)
      expect(result.operation).to eq("read")
    end
  end
end

RSpec.shared_examples "a mutating action" do |action_name, operation, params|
  it_behaves_like "an executor action", action_name, operation, params

  describe "execute: #{action_name}" do
    it "returns a success Result with snapshots" do
      result = executor.execute(action_name, params)
      expect(result).to be_a(Wild::AdminTools::Result)
      expect(result.status).to eq(:success)
      expect(result.operation).to eq(operation)
    end

    it "calls adapter write methods" do
      executor.execute(action_name, params)
      expect(adapter.write_methods_called).not_to be_empty
    end
  end
end
