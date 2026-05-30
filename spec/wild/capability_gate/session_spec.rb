# frozen_string_literal: true

RSpec.describe Wild::CapabilityGate::Session do
  let(:registry) do
    caps = [
      Wild::CapabilityGate::Capability.new(
        name: :basic_introspection, description: "Read-only", risk_level: :standard
      ),
      Wild::CapabilityGate::Capability.new(
        name: :admin_tools, description: "Admin ops", risk_level: :critical,
        prerequisites: [
          Wild::CapabilityGate::Prerequisite.new(
            type: :config_value, key: "admin_enabled", value: true
          )
        ]
      )
    ]
    Wild::CapabilityGate::Registry.new(caps)
  end

  let(:grants) do
    [
      Wild::CapabilityGate::Grant.new(caller_id: "*", capabilities: [:basic_introspection]),
      Wild::CapabilityGate::Grant.new(caller_id: "admin-agent", capabilities: %i[basic_introspection admin_tools])
    ]
  end

  let(:evaluator) { Wild::CapabilityGate::Evaluator.new(registry: registry, grants: grants) }

  describe "#initialize" do
    it "generates a UUID id by default" do
      session = described_class.new
      expect(session.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "accepts a custom id" do
      session = described_class.new(id: "test-session-1")
      expect(session.id).to eq("test-session-1")
    end

    it "records created_at timestamp" do
      session = described_class.new
      expect(session.created_at).to be_within(1).of(Time.now.utc)
    end

    it "starts with an empty cache" do
      session = described_class.new
      expect(session.cache_size).to eq(0)
    end
  end

  describe "#evaluate" do
    it "runs the full evaluator pipeline on first call" do
      session = described_class.new
      result = session.evaluate(evaluator, caller_id: "any-agent", capability_name: :basic_introspection)

      expect(result).to be_allowed
      expect(session.cache_size).to eq(1)
    end

    it "returns cached result on subsequent calls" do
      session = described_class.new

      result1 = session.evaluate(evaluator, caller_id: "any-agent", capability_name: :basic_introspection)
      result2 = session.evaluate(evaluator, caller_id: "any-agent", capability_name: :basic_introspection)

      expect(result1).to be(result2)
      expect(session.cache_size).to eq(1)
    end

    it "caches denial results too" do
      session = described_class.new

      result1 = session.evaluate(evaluator, caller_id: "any-agent", capability_name: :nonexistent)
      result2 = session.evaluate(evaluator, caller_id: "any-agent", capability_name: :nonexistent)

      expect(result1).to be(result2)
      expect(result1).to be_denied
    end

    it "caches separately per caller" do
      session = described_class.new

      result_a = session.evaluate(evaluator, caller_id: "admin-agent", capability_name: :basic_introspection)
      result_b = session.evaluate(evaluator, caller_id: "other-agent", capability_name: :basic_introspection)

      expect(result_a).not_to be(result_b)
      expect(session.cache_size).to eq(2)
    end

    it "caches separately per capability" do
      session = described_class.new

      session.evaluate(evaluator, caller_id: "admin-agent", capability_name: :basic_introspection)
      session.evaluate(
        evaluator, caller_id: "admin-agent", capability_name: :admin_tools,
                   context: { "admin_enabled" => true }
      )

      expect(session.cache_size).to eq(2)
    end

    it "does not re-evaluate when context changes within session" do
      session = described_class.new

      result1 = session.evaluate(
        evaluator, caller_id: "admin-agent", capability_name: :admin_tools,
                   context: { "admin_enabled" => false }
      )

      result2 = session.evaluate(
        evaluator, caller_id: "admin-agent", capability_name: :admin_tools,
                   context: { "admin_enabled" => true }
      )

      expect(result1).to be(result2)
      expect(result1).to be_denied
    end
  end

  describe "#cached?" do
    it "returns false before evaluation" do
      session = described_class.new
      expect(session.cached?(caller_id: "any-agent", capability_name: :basic_introspection)).to be false
    end

    it "returns true after evaluation" do
      session = described_class.new
      session.evaluate(evaluator, caller_id: "any-agent", capability_name: :basic_introspection)
      expect(session.cached?(caller_id: "any-agent", capability_name: :basic_introspection)).to be true
    end
  end

  describe "#expired?" do
    it "is not expired when fresh" do
      session = described_class.new(ttl: 3600)
      expect(session).not_to be_expired
    end

    it "is expired when TTL exceeded" do
      session = described_class.new(ttl: 0)
      expect(session).to be_expired
    end
  end

  describe "new session starts clean" do
    it "a new session does not share cache with another session" do
      session1 = described_class.new
      session1.evaluate(evaluator, caller_id: "any-agent", capability_name: :basic_introspection)

      session2 = described_class.new
      expect(session2.cache_size).to eq(0)
      expect(session2.cached?(caller_id: "any-agent", capability_name: :basic_introspection)).to be false
    end
  end
end
