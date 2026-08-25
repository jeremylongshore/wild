# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Privacy::Redactor do
  subject(:redactor) { described_class.new }

  describe "#redact_content" do
    it "redacts email addresses" do
      result = redactor.redact_content("Contact user@example.com today")
      expect(result).not_to include("user@example.com")
      expect(result).to include("[REDACTED]")
    end

    it "redacts IP addresses" do
      result = redactor.redact_content("Server is at 192.168.0.1")
      expect(result).to include("[REDACTED]")
    end

    it "redacts AWS access keys" do
      result = redactor.redact_content("Key is AKIAIOSFODNN7EXAMPLE")
      expect(result).not_to include("AKIAIOSFODNN7EXAMPLE")
    end

    it "redacts GitHub tokens" do
      token = "ghp_#{"a" * 36}"
      result = redactor.redact_content("token=#{token}")
      expect(result).not_to include(token)
    end

    it "redacts absolute paths when strip_absolute_paths is true" do
      result = redactor.redact_content("File at /home/user/secrets.yml")
      expect(result).not_to include("/home/user/secrets.yml")
    end

    it "preserves absolute paths when strip_absolute_paths is false" do
      Wild.configure { |c| c.telemetry.pipeline.strip_absolute_paths = false }
      result = redactor.redact_content("/usr/bin/ruby", config: Wild.config.telemetry.pipeline)
      expect(result).to include("/usr/bin/ruby")
    end

    it "redacts code blocks when strip_file_contents is true" do
      content = "Check this:\n```python\nsecret='abc'\n```"
      result = redactor.redact_content(content)
      expect(result).not_to include("secret='abc'")
    end

    it "preserves code blocks when strip_file_contents is false" do
      Wild.configure { |c| c.telemetry.pipeline.strip_file_contents = false }
      content = "Check:\n```python\nx=1\n```"
      result = redactor.redact_content(content, config: Wild.config.telemetry.pipeline)
      expect(result).to include("x=1")
    end

    it "uses custom redaction marker" do
      Wild.configure { |c| c.telemetry.pipeline.redaction_marker = "***" }
      result = redactor.redact_content("email: test@test.com", config: Wild.config.telemetry.pipeline)
      expect(result).to include("***")
    end

    it "applies custom patterns" do
      Wild.configure { |c| c.telemetry.pipeline.custom_patterns = [/MY_SECRET_KEY/] }
      result = redactor.redact_content("password=MY_SECRET_KEY", config: Wild.config.telemetry.pipeline)
      expect(result).not_to include("MY_SECRET_KEY")
    end

    it "returns empty string for empty input" do
      expect(redactor.redact_content("")).to eq("")
    end

    it "returns clean content unchanged" do
      clean = "The test suite ran and passed in 2.3 seconds"
      expect(redactor.redact_content(clean)).to eq(clean)
    end
  end

  describe "#redact_turn" do
    it "returns a new Turn with redacted content" do
      turn = make_turn(content: "email: user@example.com")
      result = redactor.redact_turn(turn)
      expect(result).to be_a(Wild::Telemetry::Pipeline::Models::Turn)
      expect(result.content).to include("[REDACTED]")
    end

    it "preserves role, timestamp, and non-sensitive metadata" do
      ts = Time.utc(2026, 1, 1)
      turn = make_turn(role: :assistant, content: "hello", timestamp: ts, metadata: { k: "v" })
      result = redactor.redact_turn(turn)
      expect(result.role).to eq(:assistant)
      expect(result.timestamp).to eq(ts)
      expect(result.metadata).to eq({ k: "v" })
    end

    it "redacts secrets nested inside turn metadata (f-l03-1)" do
      turn = make_turn(
        content: "exec",
        metadata: { tool_name: "exec", tool_input: { "api_key" => "AKIAIOSFODNN7EXAMPLE" } }
      )
      result = redactor.redact_turn(turn)
      expect(result.metadata[:tool_input]["api_key"]).not_to include("AKIAIOSFODNN7EXAMPLE")
      expect(result.metadata[:tool_input]["api_key"]).to include("[REDACTED]")
      expect(result.metadata[:tool_name]).to eq("exec")
    end

    it "raises PrivacyError for non-Turn input" do
      expect { redactor.redact_turn("not a turn") }
        .to raise_error(Wild::Telemetry::Pipeline::PrivacyError)
    end
  end

  describe "#redact_metadata" do
    let(:metadata) do
      {
        tool_name: "exec",
        tool_input: {
          "api_key" => "AKIAIOSFODNN7EXAMPLE",
          "notes" => ["contact bob@example.com", "not secret"],
          "count" => 3,
          "enabled" => true
        }
      }
    end
    let(:result) { redactor.redact_metadata(metadata) }

    it "scrubs secret strings, including inside arrays" do
      expect(result[:tool_input]["api_key"]).to include("[REDACTED]")
      expect(result[:tool_input]["notes"].first).to include("[REDACTED]")
    end

    it "leaves non-string values and hash keys untouched" do
      expect(result[:tool_input]["notes"][1]).to eq("not secret")
      expect(result[:tool_input]["count"]).to eq(3)
      expect(result[:tool_input]["enabled"]).to be(true)
      expect(result.keys).to eq(metadata.keys)
      expect(result[:tool_input].keys).to eq(metadata[:tool_input].keys)
    end

    it "returns nil for nil metadata" do
      expect(redactor.redact_metadata(nil)).to be_nil
    end

    it "returns an empty hash for empty metadata" do
      expect(redactor.redact_metadata({})).to eq({})
    end
  end

  describe "#redact_transcript" do
    it "returns a new Transcript with all turns redacted" do
      t = make_transcript(turns: turns_with_sensitive_content)
      result = redactor.redact_transcript(t)
      expect(result).to be_a(Wild::Telemetry::Pipeline::Models::Transcript)
      result.turns.each do |turn|
        expect(turn.content).not_to include("user@example.com")
      end
    end

    it "adds redacted: true to metadata" do
      t = make_transcript
      result = redactor.redact_transcript(t)
      expect(result.metadata[:redacted]).to be(true)
    end

    it "preserves source_type, source_id, and created_at" do
      t = make_transcript(source_type: :claude_code, source_id: "session-1")
      result = redactor.redact_transcript(t)
      expect(result.source_type).to eq(:claude_code)
      expect(result.source_id).to eq("session-1")
      expect(result.created_at).to eq(t.created_at)
    end

    it "raises PrivacyError for non-Transcript input" do
      expect { redactor.redact_transcript("bad") }
        .to raise_error(Wild::Telemetry::Pipeline::PrivacyError)
    end
  end
end
