# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Result do
  subject(:result) do
    described_class.new(
      status: status,
      action: "inspect_job",
      operation: "read",
      data: { job: { id: "123" } },
      metadata: { duration_ms: 1.5 }
    )
  end

  describe "default values" do
    let(:minimal) { described_class.new(status: :success, action: "test", operation: "read") }

    it "defaults data to empty hash" do
      expect(minimal.data).to eq({})
    end

    it "defaults snapshots to nil" do
      expect(minimal.before_snapshot).to be_nil
      expect(minimal.after_snapshot).to be_nil
    end

    it "defaults metadata to empty hash" do
      expect(minimal.metadata).to eq({})
    end
  end

  describe "immutability" do
    let(:status) { :success }

    it "is frozen" do
      expect(result).to be_frozen
    end
  end

  describe "#success?" do
    context "when status is :success" do
      let(:status) { :success }

      it { is_expected.to be_success }
    end

    context "when status is :preview" do
      let(:status) { :preview }

      it { is_expected.not_to be_success }
    end
  end

  describe "#preview?" do
    context "when status is :preview" do
      let(:status) { :preview }

      it { is_expected.to be_preview }
    end

    context "when status is :success" do
      let(:status) { :success }

      it { is_expected.not_to be_preview }
    end
  end

  describe "#denied?" do
    context "when status is :denied" do
      let(:status) { :denied }

      it { is_expected.to be_denied }
    end
  end

  describe "#error?" do
    context "when status is :error" do
      let(:status) { :error }

      it { is_expected.to be_error }
    end
  end

  describe "pattern matching" do
    let(:status) { :success }

    it "supports pattern matching on status" do
      matched = case result
                in { status: :success, action: String => action }
                  action
                else
                  nil
                end
      expect(matched).to eq("inspect_job")
    end
  end
end
