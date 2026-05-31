# frozen_string_literal: true

RSpec.describe Wild::AdminTools::Guard::ParameterValidator do
  subject(:validator) { described_class.new }

  let(:policy) { valid_policy_config }

  delegate :action, to: :policy

  describe "#validate" do
    context "with valid params for a string-keyed required param" do
      it "returns valid: true with the params" do
        result = validator.validate({ job_id: "abc-123" }, action("inspect_job"))
        expect(result[:valid]).to be(true)
        expect(result[:params]).to include(job_id: "abc-123")
      end
    end

    context "when a required param is missing" do
      it "returns valid: false with an errors array" do
        result = validator.validate({}, action("inspect_job"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/Missing required parameter.*job_id/i))
      end
    end

    context "when an unknown param is provided" do
      it "returns valid: false mentioning the unknown key" do
        result = validator.validate({ job_id: "x1", bogus: "val" }, action("retry_job"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/Unknown parameter.*bogus/i))
      end
    end

    context "when a string param receives an integer" do
      it "returns valid: false with a type error" do
        result = validator.validate({ job_id: 42 }, action("inspect_job"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/job_id must be a string/i))
      end
    end

    context "when an integer param is out of range" do
      it "returns valid: false with a range error" do
        params = { filter: { "queue_name" => "default" }, max_count: 500 }
        result = validator.validate(params, action("retry_jobs_by_filter"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/max_count must be <=\s*100/i))
      end
    end

    context "when a string param fails format validation" do
      it "returns valid: false with a format error" do
        result = validator.validate({ job_id: "bad format!" }, action("inspect_job"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/job_id.*invalid format/i))
      end
    end

    context "when a string param exceeds max_length" do
      it "returns valid: false with a length error" do
        long_key = "x" * 600
        result = validator.validate({ cache_key: long_key }, action("inspect_cache_key"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/cache_key.*too long/i))
      end
    end

    context "with boolean params" do
      it "accepts true and false" do
        params = { flag_name: "my_flag", enabled: true }
        result = validator.validate(params, action("toggle_flag"))
        expect(result[:valid]).to be(true)
      end

      it "accepts false as a valid boolean" do
        params = { flag_name: "my_flag", enabled: false }
        result = validator.validate(params, action("toggle_flag"))
        expect(result[:valid]).to be(true)
      end
    end

    context "when a boolean param receives a non-boolean value" do
      it "returns valid: false with a boolean error" do
        params = { flag_name: "my_flag", enabled: "yes" }
        result = validator.validate(params, action("toggle_flag"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/enabled must be a boolean/i))
      end
    end

    context "when an object param has fewer properties than min_properties" do
      it "returns valid: false with a properties error" do
        result = validator.validate({ filter: {} }, action("retry_jobs_by_filter"))
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include(match(/filter must have at least 1 propert/i))
      end
    end

    context "when an optional param with a default is omitted" do
      it "applies the default value in the returned params" do
        params = { filter: { "queue_name" => "critical" } }
        result = validator.validate(params, action("retry_jobs_by_filter"))
        expect(result[:valid]).to be(true)
        expect(result[:params][:max_count]).to eq(10)
      end
    end

    context "when multiple params are invalid simultaneously" do
      it "collects all errors before returning" do
        result = validator.validate({ job_id: 99, bogus_key: "x" }, action("inspect_job"))
        expect(result[:valid]).to be(false)
        expect(result[:errors].size).to be >= 2
      end
    end
  end
end
