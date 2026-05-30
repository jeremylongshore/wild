# frozen_string_literal: true

RSpec.describe Wild::Hooks::McpServer::ToolHandler do
  describe ".wrap" do
    it "returns the block's value when the block does not raise" do
      result = described_class.wrap { 42 }
      expect(result).to eq(42)
    end

    it "re-raises StandardError when no error_formatter is supplied" do
      expect { described_class.wrap { raise "boom" } }
        .to raise_error(RuntimeError, "boom")
    end

    it "passes the StandardError to error_formatter and returns its value" do
      captured = nil
      formatter = lambda do |err|
        captured = err
        :handled
      end

      result = described_class.wrap(error_formatter: formatter) { raise "boom" }

      expect(result).to eq(:handled)
      expect(captured).to be_a(RuntimeError)
      expect(captured.message).to eq("boom")
    end

    it "lets Interrupt propagate even with an error_formatter" do
      called = false
      formatter = ->(_e) { called = true }

      expect do
        described_class.wrap(error_formatter: formatter) { raise Interrupt }
      end.to raise_error(Interrupt)
      expect(called).to be(false)
    end

    it "catches subclasses of StandardError" do
      formatter = ->(e) { e.class.name }
      custom = Class.new(StandardError)

      result = described_class.wrap(error_formatter: formatter) do
        raise custom, "specific"
      end

      expect(result).to eq(custom.name)
    end
  end
end
