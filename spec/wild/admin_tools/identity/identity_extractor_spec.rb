# frozen_string_literal: true

require "spec_helper"

RSpec.describe Wild::AdminTools::Identity::IdentityExtractor do
  subject(:extractor) { described_class.new }

  describe "#extract" do
    context "with nil context" do
      it "returns anonymous session" do
        session = extractor.extract(nil)
        expect(session).to be_anonymous
        expect(session.caller_type).to eq("anonymous")
        expect(session.authenticated).to be(false)
      end
    end

    context "with empty context" do
      it "returns anonymous session" do
        session = extractor.extract({})
        expect(session).to be_anonymous
      end
    end

    context "with caller_id key" do
      it "extracts caller_id from symbol key" do
        session = extractor.extract(caller_id: "user_42")
        expect(session.caller_id).to eq("user_42")
        expect(session).to be_authenticated
      end

      it "extracts caller_id from string key" do
        session = extractor.extract("caller_id" => "user_42")
        expect(session.caller_id).to eq("user_42")
      end
    end

    context "with user_id key" do
      it "extracts user_id as caller_id" do
        session = extractor.extract(user_id: "u_123")
        expect(session.caller_id).to eq("u_123")
      end
    end

    context "with client_id key" do
      it "extracts client_id as caller_id" do
        session = extractor.extract(client_id: "service-agent")
        expect(session.caller_id).to eq("service-agent")
      end
    end

    context "with caller_type" do
      it "extracts caller_type" do
        session = extractor.extract(caller_id: "x", caller_type: "service")
        expect(session.caller_type).to eq("service")
      end

      it "defaults caller_type to user" do
        session = extractor.extract(caller_id: "x")
        expect(session.caller_type).to eq("user")
      end
    end

    context "with empty/whitespace caller_id" do
      it "treats empty string as anonymous" do
        session = extractor.extract(caller_id: "")
        expect(session).to be_anonymous
      end

      it "treats whitespace as anonymous" do
        session = extractor.extract(caller_id: "   ")
        expect(session).to be_anonymous
      end
    end

    context "with gate_result default" do
      it "always starts with not_checked" do
        session = extractor.extract(caller_id: "user_1")
        expect(session.gate_result).to eq("not_checked")
      end
    end
  end
end
