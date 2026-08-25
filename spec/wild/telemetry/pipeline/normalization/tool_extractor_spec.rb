# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Normalization::ToolExtractor do
  subject(:extractor) { described_class.new }

  describe "#extract" do
    context "with tool_use blocks" do
      it "extracts tool name from [tool_use] content" do
        turns = [make_turn(role: :assistant, content: "[tool_use] inspect_routes({})")]
        refs = extractor.extract(turns)
        expect(refs.map(&:name)).to include("inspect_routes")
      end

      it "sets action to :called for tool_use" do
        turns = [make_turn(role: :assistant, content: "[tool_use] inspect_routes({})")]
        refs = extractor.extract(turns)
        expect(refs.first.action).to eq(:called)
      end
    end

    context "with tool_result blocks" do
      it "extracts tool name from [tool_result:name] content" do
        turns = [make_turn(role: :tool, content: "[tool_result:inspect_routes] Found 42 routes")]
        refs = extractor.extract(turns)
        expect(refs.map(&:name)).to include("inspect_routes")
      end

      it "sets outcome to :success for tool_result" do
        turns = [make_turn(role: :tool, content: "[tool_result:inspect_routes] found it")]
        refs = extractor.extract(turns)
        ref = refs.find { |r| r.name == "inspect_routes" }
        expect(ref.outcome).to eq(:success)
      end
    end

    context "with mcp:// references" do
      it "extracts tool name from mcp:// URI" do
        turns = [make_turn(role: :assistant, content: "Use mcp://list_resources to get data")]
        refs = extractor.extract(turns)
        expect(refs.map(&:name)).to include("list_resources")
      end

      it "sets action to :mentioned for mcp:// refs" do
        turns = [make_turn(role: :assistant, content: "Try mcp://inspect_routes")]
        refs = extractor.extract(turns)
        ref = refs.find { |r| r.name == "inspect_routes" }
        expect(ref.action).to eq(:mentioned)
      end
    end

    context "with mcp:request content" do
      it "extracts tool name from mcp request" do
        turns = [make_turn(role: :user, content: "[mcp:request] tools/call inspect_routes({})")]
        refs = extractor.extract(turns)
        expect(refs.map(&:name)).to include("inspect_routes")
      end
    end

    context "with mcp:result content" do
      it "creates a :called/:success reference" do
        turns = [make_turn(role: :tool,
                           content: "[mcp:result] Found routes",
                           metadata: { tool_name: "inspect_routes" })]
        refs = extractor.extract(turns)
        ref = refs.find { |r| r.name == "inspect_routes" }
        expect(ref).not_to be_nil
        expect(ref.outcome).to eq(:success)
      end
    end

    context "with mcp:error content" do
      it "creates a :failed/:error reference" do
        turns = [make_turn(role: :tool,
                           content: '[mcp:error] {"code": -1}',
                           metadata: { tool_name: "bad_tool" })]
        refs = extractor.extract(turns)
        ref = refs.find { |r| r.name == "bad_tool" }
        expect(ref).not_to be_nil
        expect(ref.action).to eq(:failed)
        expect(ref.outcome).to eq(:error)
      end
    end

    context "with missing-tool patterns" do
      it "detects \"I can't find a tool for\" as :not_found" do
        turns = [make_turn(role: :assistant, content: "I can't find a tool for running tests")]
        refs = extractor.extract(turns)
        expect(refs.map(&:action)).to include(:not_found)
      end

      it "sets outcome to :not_available for not_found" do
        turns = [make_turn(role: :assistant, content: "I don't have a tool for this")]
        refs = extractor.extract(turns)
        ref = refs.find { |r| r.action == :not_found }
        expect(ref.outcome).to eq(:not_available)
      end
    end

    context "with turns array" do
      it "sets correct turn_index for each reference" do
        turns = turns_with_tool_calls
        refs = extractor.extract(turns)
        expect(refs.map(&:turn_index)).to all(be_a(Integer))
      end

      it "deduplicates same name/action/index combinations" do
        content = "[tool_use] inspect_routes({}) and also [tool_use] inspect_routes({})"
        turns = [make_turn(role: :assistant, content: content)]
        refs = extractor.extract(turns)
        keys = refs.map { |r| [r.name, r.action, r.turn_index] }
        expect(keys.uniq).to eq(keys)
      end
    end

    it "returns empty array for turns with no tool content" do
      turns = [make_turn(role: :user, content: "Hello, how are you?")]
      expect(extractor.extract(turns)).to be_empty
    end

    it "raises NormalizationError for non-Array input" do
      expect { extractor.extract("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::NormalizationError)
    end

    it "returns ToolReference objects" do
      turns = turns_with_tool_calls
      refs = extractor.extract(turns)
      expect(refs).to all(be_a(Wild::Telemetry::Pipeline::Models::ToolReference))
    end

    it "never extracts a name outside the identifier charset every capture pattern is anchored to " \
       "(f-l03-1: Redactor#redact_transcript intentionally leaves tool_references unredacted " \
       "because names can't carry a secret shape)" do
      content = <<~CONTENT
        [tool_use] inspect_routes({})
        [tool_result:inspect_routes] done
        mcp://list_resources
        I can't find a tool for this: api_key=sk-live-abcdefghijklmnopqrstuvwx
      CONTENT
      turns = [make_turn(role: :assistant, content: content)]

      refs = extractor.extract(turns)

      expect(refs).not_to be_empty
      expect(refs.map(&:name)).to all(match(/\A[a-z_][a-z0-9_-]*\z/i))
    end
  end
end
