# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require "tmpdir"

RSpec.describe Wild::Telemetry::Analysis do
  # F1 collapsed per-gem Configuration accessors into the central
  # Wild.config.telemetry.analysis block; the old gem-level
  # .configuration/.configure/.reset_configuration! tests are dropped.
  # This spec covers the .analyze convenience method + module identity.

  it "defines the Wild::Telemetry::Analysis module" do
    expect(described_class).to be_a(Module)
  end

  describe ".analyze" do
    it "parses a JSONL file and returns a GapReport" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test.jsonl")
        File.write(path, valid_jsonl)
        report = described_class.analyze(path)
        expect(report).to be_a(Wild::Telemetry::Analysis::Models::GapReport)
      end
    end

    it "reads thresholds from Wild.config.telemetry.analysis" do
      Wild.configure { |c| c.telemetry.analysis.denial_threshold = 0.5 }
      expect(Wild.config.telemetry.analysis.denial_threshold).to eq(0.5)
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
