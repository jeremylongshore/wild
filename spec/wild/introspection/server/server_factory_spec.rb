# frozen_string_literal: true

RSpec.describe Wild::Introspection::Server::ServerFactory do
  include Wild::Introspection::TestSupport::TestConfigHelper

  before { configure_with_test_fixtures! }

  describe ".create" do
    subject(:server) { described_class.create(server_context: authenticated_server_context) }

    it "returns an MCP::Server instance" do
      expect(server).to be_a(MCP::Server)
    end

    it "sets the correct server name" do
      expect(server.name).to eq("wild-rails-safe-introspection")
    end

    it "sets the version from VERSION constant" do
      expect(server.version).to eq(Wild::VERSION)
    end

    it "registers exactly 3 tools" do
      expect(server.tools.size).to eq(3)
    end

    it "registers the correct tool names" do
      tool_names = server.tools.keys
      expect(tool_names).to contain_exactly(
        "inspect_model_schema",
        "lookup_record_by_id",
        "find_records_by_filter"
      )
    end

    it "passes server_context through" do
      expect(server.server_context).to eq(authenticated_server_context)
    end
  end

  describe "TOOLS constant" do
    it "is frozen" do
      expect(described_class::TOOLS).to be_frozen
    end

    it "contains exactly 3 tool classes" do
      expect(described_class::TOOLS.size).to eq(3)
    end
  end
end
