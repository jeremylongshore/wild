# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Analysis::Models::ExportHeader do
  subject(:header) { build_header }

  describe "#valid?" do
    it "returns true for a complete header" do
      expect(header).to be_valid
    end

    it "returns false when export_type is wrong" do
      expect(build_header("export_type" => "wrong")).not_to be_valid
    end

    it "returns false when schema_version is missing" do
      expect(build_header("schema_version" => nil)).not_to be_valid
    end

    it "returns false when source_id is missing" do
      expect(build_header("source_id" => nil)).not_to be_valid
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      h = header.to_h
      expect(h).to include(:export_type, :schema_version, :source_id, :time_range, :record_counts)
    end
  end

  describe "attribute readers" do
    it "exposes export_type" do
      expect(header.export_type).to eq("session_telemetry")
    end

    it "exposes schema_version" do
      expect(header.schema_version).to eq("1.0")
    end

    it "exposes source_id" do
      expect(header.source_id).to eq("test-source-001")
    end

    it "defaults time_range to empty hash" do
      h = described_class.new("export_type" => "session_telemetry", "schema_version" => "1.0", "source_id" => "x")
      expect(h.time_range).to eq({})
    end

    it "defaults record_counts to empty hash" do
      h = described_class.new("export_type" => "session_telemetry", "schema_version" => "1.0", "source_id" => "x")
      expect(h.record_counts).to eq({})
    end
  end
end
