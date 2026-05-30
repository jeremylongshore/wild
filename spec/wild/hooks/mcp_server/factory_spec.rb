# frozen_string_literal: true

RSpec.describe Wild::Hooks::McpServer::Factory do
  describe ".create" do
    let(:tools) { [Class.new(MCP::Tool)] }

    it "returns an MCP::Server" do
      server = described_class.create(
        name: "wild-test",
        version: "1.0.0",
        tools: tools
      )
      expect(server).to be_a(MCP::Server)
    end

    it "propagates name, version, tools, and server_context to MCP::Server" do
      allow(MCP::Server).to receive(:new).and_call_original
      described_class.create(
        name: "wild-introspection",
        version: "0.1.0",
        tools: tools,
        server_context: { caller_id: "agent-42" }
      )
      expect(MCP::Server).to have_received(:new).with(
        name: "wild-introspection",
        version: "0.1.0",
        tools: tools,
        server_context: { caller_id: "agent-42" }
      )
    end

    it "defaults server_context to an empty hash when omitted" do
      allow(MCP::Server).to receive(:new).and_call_original
      described_class.create(name: "x", version: "0.0.0", tools: tools)
      expect(MCP::Server).to have_received(:new).with(
        hash_including(server_context: {})
      )
    end
  end
end
