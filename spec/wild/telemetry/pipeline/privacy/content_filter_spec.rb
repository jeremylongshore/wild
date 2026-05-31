# frozen_string_literal: true

RSpec.describe Wild::Telemetry::Pipeline::Privacy::ContentFilter do
  subject(:filter) { described_class.new }

  describe "#sensitive?" do
    it "detects email addresses" do
      expect(filter.sensitive?("My email is user@example.com")).to be(true)
    end

    it "detects IP addresses" do
      expect(filter.sensitive?("Server at 192.168.1.100")).to be(true)
    end

    it "detects API key patterns" do
      expect(filter.sensitive?("api_key=sk-abc123def456ghi789jkl")).to be(true)
    end

    it "detects AWS access keys" do
      expect(filter.sensitive?("Key: AKIAIOSFODNN7EXAMPLE")).to be(true)
    end

    it "detects GitHub tokens" do
      token = "ghp_#{"a" * 36}"
      expect(filter.sensitive?("token=#{token}")).to be(true)
    end

    it "detects absolute paths when strip_absolute_paths is true" do
      expect(filter.sensitive?("File at /home/user/secrets/key.pem")).to be(true)
    end

    it "does not detect absolute paths when strip_absolute_paths is false" do
      Wild.configure { |c| c.telemetry.pipeline.strip_absolute_paths = false }
      expect(filter.sensitive?("Path: /usr/bin/ruby", config: Wild.config.telemetry.pipeline))
        .to be(false)
    end

    it "detects code blocks as file contents when strip_file_contents is true" do
      content = "Here:\n```ruby\nsecret = 'foo'\n```"
      expect(filter.sensitive?(content)).to be(true)
    end

    it "does not flag code blocks when strip_file_contents is false" do
      Wild.configure { |c| c.telemetry.pipeline.strip_file_contents = false }
      content = "Here:\n```ruby\nx = 1\n```"
      expect(filter.sensitive?(content, config: Wild.config.telemetry.pipeline)).to be(false)
    end

    it "returns false for clean content" do
      expect(filter.sensitive?("The test passed successfully")).to be(false)
    end

    it "returns false for empty string" do
      expect(filter.sensitive?("")).to be(false)
    end

    it "detects custom patterns" do
      Wild.configure { |c| c.telemetry.pipeline.custom_patterns = [/SECRET_WORD/] }
      expect(filter.sensitive?("password is SECRET_WORD here", config: Wild.config.telemetry.pipeline))
        .to be(true)
    end

    it "does not detect custom patterns when not configured" do
      expect(filter.sensitive?("password is SECRET_WORD here")).to be(false)
    end
  end

  describe "#patterns_matching" do
    it "returns matching patterns" do
      patterns = filter.patterns_matching("email: user@example.com")
      expect(patterns).not_to be_empty
    end

    it "returns empty array for clean content" do
      patterns = filter.patterns_matching("clean content here")
      expect(patterns).to eq([])
    end

    it "returns multiple patterns for multiple hits" do
      content = "user@example.com connected from 10.0.0.1"
      patterns = filter.patterns_matching(content)
      expect(patterns.size).to be >= 2
    end
  end
end
