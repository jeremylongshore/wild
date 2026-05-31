# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Server::ResponseFormatter do
  describe ".format" do
    context "with a success result" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :success,
          action: "inspect_job",
          operation: "read",
          data: { job_id: "j1", status: "dead" },
          metadata: { duration_ms: 1.5 }
        )
      end

      it "returns an MCP::Tool::Response with error: false" do
        response = described_class.format(result)
        expect(response).to be_a(MCP::Tool::Response)
        expect(response.error?).to be false
      end

      it "includes structured_content with success fields" do
        response = described_class.format(result)
        body = response.structured_content
        expect(body[:status]).to eq("success")
        expect(body[:action]).to eq("inspect_job")
        expect(body[:operation]).to eq("read")
        expect(body[:data]).to eq({ job_id: "j1", status: "dead" })
      end
    end

    context "with a success result including snapshots" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :success,
          action: "retry_job",
          operation: "mutate",
          data: { job_id: "j1", retried: true },
          before_snapshot: { status: "dead" },
          after_snapshot: { status: "enqueued" },
          metadata: { duration_ms: 2.3 }
        )
      end

      it "includes before and after snapshots" do
        body = described_class.format(result).structured_content
        expect(body[:before_snapshot]).to eq({ status: "dead" })
        expect(body[:after_snapshot]).to eq({ status: "enqueued" })
      end
    end

    context "with a preview result" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :preview,
          action: "retry_job",
          operation: "mutate",
          data: { job: { job_id: "j1" }, will_retry: true },
          metadata: { nonce: "wnc_abc123", requires_confirmation: true }
        )
      end

      it "returns error: false with nonce in metadata" do
        response = described_class.format(result)
        expect(response.error?).to be false
        body = response.structured_content
        expect(body[:status]).to eq("preview")
        expect(body[:metadata][:nonce]).to eq("wnc_abc123")
        expect(body[:metadata][:requires_confirmation]).to be true
      end
    end

    context "with a denied result" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :denied,
          action: "retry_job",
          operation: "unknown",
          metadata: { reason: "gate_denied" }
        )
      end

      it "returns error: true with reason" do
        response = described_class.format(result)
        expect(response.error?).to be true
        body = response.structured_content
        expect(body[:status]).to eq("denied")
        expect(body[:reason]).to eq("gate_denied")
      end
    end

    context "with a denied result for rate limiting" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :denied,
          action: "retry_job",
          operation: "unknown",
          metadata: { reason: "rate_limited", retry_after_seconds: 45 }
        )
      end

      it "includes denial details in body" do
        body = described_class.format(result).structured_content
        expect(body[:reason]).to eq("rate_limited")
        expect(body[:retry_after_seconds]).to eq(45)
      end
    end

    context "with an error result" do
      let(:result) do
        Wild::AdminTools::Result.new(
          status: :error,
          action: "inspect_job",
          operation: "unknown",
          metadata: { message: "Adapter connection failed" }
        )
      end

      it "returns error: true with message" do
        response = described_class.format(result)
        expect(response.error?).to be true
        body = response.structured_content
        expect(body[:status]).to eq("error")
        expect(body[:message]).to eq("Adapter connection failed")
      end
    end
  end

  describe ".format_error" do
    it "formats a StandardError into an error response" do
      error = StandardError.new("something broke")
      response = described_class.format_error("retry_job", error)

      expect(response).to be_a(MCP::Tool::Response)
      expect(response.error?).to be true
      body = response.structured_content
      expect(body[:status]).to eq("error")
      expect(body[:action]).to eq("retry_job")
      expect(body[:message]).to eq("something broke")
    end
  end
end
