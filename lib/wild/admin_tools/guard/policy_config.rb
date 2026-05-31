# frozen_string_literal: true

require "yaml"

module Wild
  module AdminTools
    module Guard
      # Parses and validates config/action_policy.yml.
      #
      # Use PolicyConfig.load(path) or PolicyConfig.from_hash(hash) to obtain
      # a frozen, validated instance. Validation is exhaustive — all errors are
      # collected before raising, so callers see every problem at once.
      class PolicyConfig
        VALID_OPERATIONS   = %w[read mutate mutate_destructive].freeze
        RATE_LIMIT_PATTERN = %r{\A\d+/minute\z}
        NAME_PATTERN       = /\A[a-z][a-z0-9_]{0,63}\z/
        REQUIRED_DEFAULTS  = %w[rate_limit blast_radius_cap requires_confirmation nonce_ttl_seconds].freeze
        REQUIRED_CEILINGS  = %w[max_rate_limit max_blast_radius max_nonce_ttl_seconds min_nonce_ttl_seconds].freeze
        REQUIRED_GLOBALS   = %w[all_mutations all_reads].freeze

        attr_reader :version, :defaults, :hard_ceilings, :global_rate_limits, :actions, :categories

        def self.load(path)
          raw = YAML.safe_load_file(path, permitted_classes: [], symbolize_names: false)
          from_hash(raw)
        rescue Errno::ENOENT => e
          raise ConfigurationError, "Policy file not found: #{e.message}"
        rescue Psych::Exception => e
          raise ConfigurationError, "Policy file is not valid YAML: #{e.message}"
        end

        def self.from_hash(hash)
          errors = []
          new(hash, errors).tap do |config|
            raise ConfigurationError, errors.join("; ") unless errors.empty?

            config.freeze_self
          end
        end

        def action(name)
          @actions[name.to_s]
        end

        def freeze_self
          @actions    = @actions.freeze
          @categories = @categories.freeze
          freeze
        end

        private

        def initialize(hash, errors)
          @raw    = hash
          @errors = errors
          @actions    = {}
          @categories = {}
          @version = @defaults = @hard_ceilings = @global_rate_limits = nil
          build_from_valid_raw
        end

        def build_from_valid_raw
          Validator.new(@raw, @errors).validate
          return unless @errors.empty?

          assign_top_level_fields
          build_actions
        end

        def assign_top_level_fields
          @version          = @raw["version"]
          @defaults         = @raw["defaults"].freeze
          @hard_ceilings    = @raw["hard_ceilings"].freeze
          @global_rate_limits = @raw["global_rate_limits"].freeze
        end

        def build_actions
          @raw["action_categories"].each do |cat_name, cat_body|
            validate_category_name(cat_name)
            build_category_actions(cat_name, cat_body)
            @categories[cat_name] = cat_body.freeze
          end
        end

        def validate_category_name(name)
          return if NAME_PATTERN.match?(name.to_s)

          @errors << "category name '#{name}' does not match #{NAME_PATTERN.source}"
        end

        def build_category_actions(cat_name, cat_body)
          actions_list = cat_body.is_a?(Hash) ? Array(cat_body["actions"]) : []
          actions_list.each { |a| process_action(a, cat_name) }
        end

        def process_action(action_hash, cat_name)
          return @errors << "action in category '#{cat_name}' is not a Hash" unless action_hash.is_a?(Hash)

          name = action_hash["name"].to_s
          check_action_name_format(name)
          check_action_duplicate(name, cat_name)
          ActionValidator.new(action_hash, name, @hard_ceilings, @errors).validate
          @actions[name] = action_hash.freeze
        end

        def check_action_name_format(name)
          return if NAME_PATTERN.match?(name)

          @errors << "action name '#{name}' does not match #{NAME_PATTERN.source}"
        end

        def check_action_duplicate(name, cat_name)
          return unless @actions.key?(name)

          @errors << "duplicate action name '#{name}' found again in category '#{cat_name}'"
        end

        # Validates the top-level structure of the policy hash.
        class Validator
          def initialize(raw, errors)
            @raw    = raw
            @errors = errors
          end

          def validate
            validate_version
            validate_section("defaults", PolicyConfig::REQUIRED_DEFAULTS)
            validate_section("hard_ceilings", PolicyConfig::REQUIRED_CEILINGS)
            validate_section("global_rate_limits", PolicyConfig::REQUIRED_GLOBALS)
            validate_categories_present
          end

          private

          def validate_version
            @errors << "version must be present and equal to 1" unless @raw["version"] == 1
          end

          def validate_section(key, required_fields)
            section = @raw[key]
            if section.nil?
              @errors << "#{key} section is required"
              return
            end
            required_fields.each { |f| @errors << "#{key}.#{f} is required" unless section.key?(f) }
          end

          def validate_categories_present
            @errors << "action_categories is required and must be a Hash" unless @raw["action_categories"].is_a?(Hash)
          end
        end

        # Validates a single action hash against field, operation, and ceiling rules.
        class ActionValidator
          def initialize(action_hash, name, ceilings, errors)
            @action   = action_hash
            @name     = name
            @ceilings = ceilings
            @errors   = errors
          end

          def validate
            validate_required_keys
            validate_operation
            validate_confirmation_consistency
            validate_rate_limit
            validate_blast_radius
            validate_nonce_ttl
          end

          private

          def validate_required_keys
            %w[name operation requires_confirmation].each do |field|
              @errors << "action '#{@name}' missing required field '#{field}'" unless @action.key?(field)
            end
          end

          def validate_operation
            op = @action["operation"]
            return if PolicyConfig::VALID_OPERATIONS.include?(op)

            @errors << "action '#{@name}' operation '#{op}' must be one of: #{PolicyConfig::VALID_OPERATIONS.join(", ")}" # rubocop:disable Layout/LineLength
          end

          def validate_confirmation_consistency
            op    = @action["operation"]
            needs = @action["requires_confirmation"]
            if op == "read" && needs != false
              @errors << "action '#{@name}' is a read operation and must have requires_confirmation: false"
            elsif %w[mutate mutate_destructive].include?(op) && needs != true
              @errors << "action '#{@name}' is a #{op} operation and must have requires_confirmation: true"
            end
          end

          def validate_rate_limit
            rl = @action["rate_limit"]
            return unless rl

            unless PolicyConfig::RATE_LIMIT_PATTERN.match?(rl.to_s)
              @errors << "action '#{@name}' rate_limit '#{rl}' must match format N/minute"
              return
            end
            check_rate_limit_ceiling(rl)
          end

          def check_rate_limit_ceiling(rate_limit)
            max    = parse_rate_limit(@ceilings["max_rate_limit"])[:count]
            actual = parse_rate_limit(rate_limit)[:count]
            return if actual <= max

            @errors << "action '#{@name}' rate_limit #{rate_limit} exceeds hard ceiling #{@ceilings["max_rate_limit"]}"
          end

          def validate_blast_radius
            cap = @action["blast_radius_cap"]
            return unless cap.is_a?(Integer)

            max = @ceilings["max_blast_radius"]
            return if cap <= max

            @errors << "action '#{@name}' blast_radius_cap #{cap} exceeds hard ceiling #{max}"
          end

          def validate_nonce_ttl
            ttl = @action["nonce_ttl_seconds"]
            return unless ttl.is_a?(Integer)

            min_ttl = @ceilings["min_nonce_ttl_seconds"]
            max_ttl = @ceilings["max_nonce_ttl_seconds"]
            return if ttl.between?(min_ttl, max_ttl)

            @errors << "action '#{@name}' nonce_ttl_seconds #{ttl} must be between #{min_ttl} and #{max_ttl}"
          end

          def parse_rate_limit(str)
            count = str.to_s.split("/").first.to_i
            { count: count, window: 60 }
          end
        end
      end
    end
  end
end
