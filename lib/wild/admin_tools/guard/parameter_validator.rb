# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      # Validates a params hash against an action's parameter schema from the policy config.
      #
      # @example
      #   result = ParameterValidator.new.validate({ job_id: "abc123" }, action_config)
      #   result[:valid]  # => true
      #   result[:params] # => { job_id: "abc123", limit: 50 }
      class ParameterValidator
        TYPE_MAP = {
          "string" => String,
          "integer" => Integer,
          "object" => Hash
        }.freeze

        def validate(params, action_config)
          schema    = action_config["parameters"] || {}
          required  = schema["required"] || []
          optional  = schema["optional"] || []
          all_specs = required + optional

          errors = []
          errors.concat(validate_required_params(params, required))
          errors.concat(validate_unknown_params(params, all_specs))
          errors.concat(validate_all_values(params, all_specs))

          return { valid: false, errors: errors } if errors.any?

          { valid: true, params: apply_defaults(params, optional) }
        end

        private

        def validate_required_params(params, required_specs)
          required_specs.filter_map do |spec|
            name = spec["name"].to_sym
            "Missing required parameter: #{spec["name"]}" unless params.key?(name)
          end
        end

        def validate_unknown_params(params, all_specs)
          declared = all_specs.to_set { |s| s["name"].to_sym }
          params.keys.filter_map do |key|
            "Unknown parameter: #{key}" unless declared.include?(key)
          end
        end

        def validate_all_values(params, all_specs)
          all_specs.each_with_object([]) do |spec, errors|
            name = spec["name"].to_sym
            next unless params.key?(name)

            errors.concat(validate_param_value(params[name], spec))
          end
        end

        def validate_param_value(value, spec)
          type   = spec["type"]
          rules  = spec["validation"] || {}
          errors = validate_type(value, type, spec["name"])
          return errors if errors.any?

          errors.concat(
            case type
            when "string"  then validate_string_param(value, rules, spec["name"])
            when "integer" then validate_integer_param(value, rules, spec["name"])
            when "boolean" then validate_boolean_param(value, spec["name"])
            when "object"  then validate_object_param(value, spec, spec["name"])
            else []
            end
          )
        end

        def validate_type(value, type, name)
          return [] if type == "boolean"

          klass = TYPE_MAP[type]
          return [] if klass && value.is_a?(klass)

          klass ? ["Parameter #{name} must be a #{type}"] : []
        end

        def validate_boolean_param(value, name)
          return [] if [true, false].include?(value)

          ["Parameter #{name} must be a boolean"]
        end

        def validate_string_param(value, rules, name)
          errors = []
          min_len = rules["min_length"]
          max_len = rules["max_length"]
          format  = rules["format"]

          errors << "Parameter #{name} is too short (min #{min_len})" if min_len && value.length < min_len
          errors << "Parameter #{name} is too long (max #{max_len})"  if max_len && value.length > max_len
          errors << "Parameter #{name} has invalid format"            if format && !Regexp.new(format).match?(value)
          errors
        end

        def validate_integer_param(value, rules, name)
          errors = []
          min = rules["min"]
          max = rules["max"]

          errors << "Parameter #{name} must be >= #{min}" if min && value < min
          errors << "Parameter #{name} must be <= #{max}" if max && value > max
          errors
        end

        def validate_object_param(value, spec, name)
          errors = []
          min_props  = spec["min_properties"]
          properties = spec["properties"]

          errors << "Parameter #{name} must have at least #{min_props} properties" \
            if min_props && value.size < min_props

          if properties.is_a?(Hash)
            declared = properties.keys.to_set
            value.each_key do |k|
              errors << "Parameter #{name} contains undeclared property: #{k}" unless declared.include?(k.to_s)
            end
          end

          errors
        end

        def apply_defaults(params, optional_specs)
          optional_specs.each_with_object(params.dup) do |spec, result|
            name = spec["name"].to_sym
            result[name] = spec["default"] if !result.key?(name) && spec.key?("default")
          end
        end
      end
    end
  end
end
