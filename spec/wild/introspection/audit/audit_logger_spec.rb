# frozen_string_literal: true

require "tmpdir"

RSpec.describe Wild::Introspection::Audit::AuditLogger do
  include Wild::Introspection::TestSupport::TestConfigHelper

  let(:log_dir) { Dir.mktmpdir }
  let(:log_path) { File.join(log_dir, "audit.jsonl") }

  let(:record) do
    Wild::Introspection::Audit::AuditRecord.new(
      tool_name: "inspect_model_schema",
      guard_result: "allowed",
      outcome: "success",
      duration_ms: 10,
      model_name: "Account"
    )
  end

  after { FileUtils.rm_rf(log_dir) }

  context "when audit_log_path is configured" do
    before do
      configure_with_test_fixtures!
      Wild::Introspection.configuration.audit_log_path = log_path
    end

    it "writes a JSONL line to the configured path" do
      described_class.log(record)

      expect(File.exist?(log_path)).to be true
      lines = File.readlines(log_path)
      expect(lines.size).to eq(1)
    end

    it "writes valid JSON on each line" do
      described_class.log(record)

      line = File.readlines(log_path).first
      parsed = JSON.parse(line)
      expect(parsed["tool_name"]).to eq("inspect_model_schema")
      expect(parsed["outcome"]).to eq("success")
    end

    it "appends multiple records" do
      3.times { described_class.log(record) }

      lines = File.readlines(log_path)
      expect(lines.size).to eq(3)
      lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
    end

    it "preserves all record fields in JSON" do
      described_class.log(record)

      parsed = JSON.parse(File.readlines(log_path).first)
      Wild::Introspection::Audit::AuditRecord::FIELDS.each do |field|
        expect(parsed).to have_key(field.to_s), "expected JSON to include #{field}"
      end
    end
  end

  context "when audit_log_path is nil" do
    before do
      configure_with_test_fixtures!
      Wild::Introspection.configuration.audit_log_path = nil
    end

    it "silently skips logging" do
      expect { described_class.log(record) }.not_to raise_error
      expect(File.exist?(log_path)).to be false
    end
  end
end
