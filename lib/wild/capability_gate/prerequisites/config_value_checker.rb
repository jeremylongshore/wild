# frozen_string_literal: true

module Wild
  module CapabilityGate
    module Prerequisites
      # Checks that a configuration key in the evaluation context matches
      # an expected value.
      #
      # Prerequisite params:
      #   key:   (String) the configuration key to look up
      #   value: (Object) the expected value
      #
      # The context hash is passed by the caller at evaluation time.
      # Both string and symbol keys are checked for robustness.
      #
      # Fail-closed: missing keys or mismatched values result in denial.
      class ConfigValueChecker
        def self.check(prerequisite, context: {})
          key = prerequisite.params[:key]
          return CheckResult.failed(details: "config_value prerequisite missing required key parameter") if key.nil?

          evaluate_value(prerequisite, context, key)
        rescue StandardError => e
          CheckResult.failed(details: "config_value check failed: #{e.class}")
        end

        def self.evaluate_value(prerequisite, context, key)
          # f-l08-1: an absent key must NEVER satisfy any expectation,
          # including a prerequisite authored without `value:` (expected ==
          # nil). Registry::ConfigLoader now refuses to load a valueless
          # config_value prerequisite at all, but this check is independent
          # defense-in-depth — a Prerequisite can also be built directly
          # (tests, a future caller) without going through the loader.
          unless key_present?(context, key)
            return CheckResult.failed(details: "config key #{key.inspect} is not present in context")
          end

          expected = prerequisite.params[:value]
          actual = lookup(context, key)

          if actual == expected
            CheckResult.passed
          else
            CheckResult.failed(
              details: "config key #{key.inspect} expected #{expected.inspect}, got #{actual.inspect}"
            )
          end
        end
        private_class_method :evaluate_value

        def self.key_present?(context, key)
          context.key?(key.to_s) || context.key?(key.to_s.to_sym)
        end
        private_class_method :key_present?

        def self.lookup(context, key)
          str_key = key.to_s
          sym_key = key.to_s.to_sym

          if context.key?(str_key)
            context[str_key]
          elsif context.key?(sym_key)
            context[sym_key]
          end
        end
        private_class_method :lookup
      end
    end
  end
end
