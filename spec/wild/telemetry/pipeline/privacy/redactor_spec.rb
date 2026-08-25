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
    describe "key-aware redaction (f-l03-1 item 1)" do
      it "redacts the whole value of a String secret-named key even though the value itself has no matching pattern" do
        result = redactor.redact_metadata({ "api_key" => "sk_live_abcdefghijklmnop" })
        expect(result["api_key"]).to eq("[REDACTED]")
      end

      it "redacts the whole value of a nested secret-named key regardless of shape" do
        result = redactor.redact_metadata({ "aws_secret" => { "value" => "not-a-known-pattern", "n" => 1 } })
        expect(result["aws_secret"]).to eq("[REDACTED]")
      end

      it "matches secret-ish key names after normalizing case and separators" do
        result = redactor.redact_metadata({ "Authorization-Token" => "whatever-this-is" })
        expect(result["Authorization-Token"]).to eq("[REDACTED]")
      end

      it "does not redact a non-secret key's whole value, only scrubs its secret leaves" do
        result = redactor.redact_metadata({ "tool_input" => { "api_key" => "AKIAIOSFODNN7EXAMPLE", "count" => 3 } })
        expect(result["tool_input"]["api_key"]).to eq("[REDACTED]")
        expect(result["tool_input"]["count"]).to eq(3)
      end
    end

    describe "secrets-only leaf scrubbing, not content-style over-redaction (f-l03-1 item 2)" do
      let(:mcp_shaped_metadata) do
        {
          method: "tools/call",
          tool_name: "resources/read",
          file_path: "/home/x/app.rb",
          remote: "git@github.com:acme/app.git",
          aws_key: "AKIAIOSFODNN7EXAMPLE"
        }
      end
      let(:result) { redactor.redact_metadata(mcp_shaped_metadata) }

      it "leaves MCP method and tool names untouched" do
        expect(result[:method]).to eq("tools/call")
        expect(result[:tool_name]).to eq("resources/read")
      end

      it "leaves an absolute file path untouched" do
        expect(result[:file_path]).to eq("/home/x/app.rb")
      end

      it "leaves a git remote URL (email-shaped) untouched" do
        expect(result[:remote]).to eq("git@github.com:acme/app.git")
      end

      it "still redacts an actual secret pattern" do
        expect(result[:aws_key]).to include("[REDACTED]")
        expect(result[:aws_key]).not_to include("AKIAIOSFODNN7EXAMPLE")
      end
    end

    describe "leaf scrubbing under non-secret-named keys" do
      let(:metadata) do
        {
          tool_name: "exec",
          tool_input: {
            "aws_key" => "AKIAIOSFODNN7EXAMPLE",
            "notes" => ["contact bob@example.com", "not secret"],
            "count" => 3,
            "enabled" => true
          }
        }
      end
      let(:result) { redactor.redact_metadata(metadata) }

      it "scrubs a secret pattern nested inside an array" do
        expect(result[:tool_input]["aws_key"]).to include("[REDACTED]")
      end

      it "leaves a non-secret-pattern string (an email) inside an array untouched, per item 2" do
        expect(result[:tool_input]["notes"].first).to eq("contact bob@example.com")
        expect(result[:tool_input]["notes"][1]).to eq("not secret")
      end

      it "leaves non-string values and hash keys untouched" do
        expect(result[:tool_input]["count"]).to eq(3)
        expect(result[:tool_input]["enabled"]).to be(true)
        expect(result.keys).to eq(metadata.keys)
        expect(result[:tool_input].keys).to eq(metadata[:tool_input].keys)
      end
    end

    describe "class preservation (f-l03-1 item 4)" do
      it "rebuilds an ActiveSupport::HashWithIndifferentAccess as the same class" do
        metadata = ActiveSupport::HashWithIndifferentAccess.new(tool_name: "exec", api_key: "sk_live_x")
        result = redactor.redact_metadata(metadata)
        expect(result).to be_a(ActiveSupport::HashWithIndifferentAccess)
        expect(result[:tool_name]).to eq("exec")
        expect(result["tool_name"]).to eq("exec")
      end
    end

    describe "depth guard and cycle detection (f-l03-1 item 5)" do
      it "raises PrivacyError instead of SystemStackError for a self-referential hash" do
        cyclic = {}
        cyclic["self"] = cyclic
        expect { redactor.redact_metadata(cyclic) }
          .to raise_error(Wild::Telemetry::Pipeline::PrivacyError, /circular/)
      end

      it "raises PrivacyError for metadata nested deeper than the depth cap" do
        deep = "leaf"
        70.times { |i| deep = { "level#{i}" => deep } }
        expect { redactor.redact_metadata(deep) }
          .to raise_error(Wild::Telemetry::Pipeline::PrivacyError, /depth/)
      end

      it "does not raise for a shared (non-cyclic) sub-hash referenced twice" do
        shared = { "count" => 1 }
        metadata = { "a" => shared, "b" => shared }
        expect { redactor.redact_metadata(metadata) }.not_to raise_error
      end
    end

    describe "Symbol leaf values (f-l03-1 item 6)" do
      it "scrubs a Symbol value the same as a String, returned as a String" do
        result = redactor.redact_metadata({ "token_hint" => :AKIAIOSFODNN7EXAMPLE })
        expect(result["token_hint"]).to be_a(String)
        expect(result["token_hint"]).to include("[REDACTED]")
      end

      # Documented per item 6: Hash *keys* are never rewritten, even when a key
      # is itself Symbol-typed and secret-shaped as a VALUE would be redacted
      # under a different key. Key-name redaction is a separate, deferred scope.
      it "does not rewrite Hash keys, only key-matched or leaf-scrubbed values" do
        result = redactor.redact_metadata({ api_key: "sk_live_abc" })
        expect(result.keys).to eq([:api_key])
      end
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

    it "scrubs secrets inside transcript-level metadata, not just turns (f-l03-1 item 3)" do
      t = make_transcript(metadata: { "api_key" => "sk_live_abcdefghijklmnop" })
      result = redactor.redact_transcript(t)
      expect(result.metadata["api_key"]).to eq("[REDACTED]")
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

    it "redacts secrets copied into a derived Intent#description (f-l03-1 security-review follow-up)" do
      secret_turn = make_turn(
        role: :user,
        content: "I need to deploy with api_key: ABCDEFGHIJKLMNOP1234 to 10.1.2.3"
      )
      intent = Wild::Telemetry::Pipeline::Models::Intent.new(
        description: "I need to deploy with api_key: ABCDEFGHIJKLMNOP1234 to 10.1.2.3",
        confidence: 0.65,
        source_turn_index: 0
      )
      t = make_transcript(turns: [secret_turn], intents: [intent])

      result = redactor.redact_transcript(t)

      description = result.intents.first.description
      expect(description).not_to include("ABCDEFGHIJKLMNOP1234")
      expect(description).not_to include("10.1.2.3")
      expect(description).to include("[REDACTED]")
    end

    it "preserves confidence and source_turn_index while redacting an intent's description" do
      intent = Wild::Telemetry::Pipeline::Models::Intent.new(
        description: "contact me at leak@example.com",
        confidence: 0.7,
        source_turn_index: 2
      )
      t = make_transcript(intents: [intent])

      redacted = redactor.redact_transcript(t).intents.first

      expect(redacted.confidence).to eq(0.7)
      expect(redacted.source_turn_index).to eq(2)
      expect(redacted.description).not_to include("leak@example.com")
    end
  end

  describe "#redact_content idempotency (f-l03-1 item 7 follow-up)" do
    it "leaves already-redacted content unchanged on a second pass, even when the marker itself " \
       "looks like a pattern the redactor scans for" do
      Wild.configure { |c| c.telemetry.pipeline.redaction_marker = "<redacted@wild.local>" }
      config = Wild.config.telemetry.pipeline

      once = redactor.redact_content("Contact me at real@user.com for help", config: config)
      twice = redactor.redact_content(once, config: config)

      expect(twice).to eq(once)
    end
  end
end
