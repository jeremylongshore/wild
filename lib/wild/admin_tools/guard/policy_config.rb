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
        # The full schema of the `defaults` section (structural completeness:
        # every one of these keys must be present, and no others are allowed,
        # see Validator#validate_defaults_known_keys).
        REQUIRED_DEFAULTS  = %w[rate_limit blast_radius_cap requires_confirmation nonce_ttl_seconds].freeze
        # The subset of `defaults` an action actually inherits when it omits a
        # key (see #process_action). `requires_confirmation` is deliberately
        # excluded: ActionValidator requires every action to declare its own
        # requires_confirmation, pinned to that action's own operation
        # (read => false, mutate/mutate_destructive => true). Silently
        # inheriting it from `defaults` would let a defaults typo mask a real
        # confirmation-safety gap, so it stays a per-action mandatory field,
        # not an inheritable one (fixes a comment/CHANGELOG claim to the
        # contrary; security-review follow-up on f-l10-6, PR #73).
        INHERITABLE_ACTION_KEYS = %w[rate_limit blast_radius_cap nonce_ttl_seconds].freeze
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

        # Shared "N/minute" -> count parser used by ActionValidator and
        # DefaultsCeilingValidator so both ceiling checks agree on how a
        # rate_limit string is read.
        def self.rate_limit_count(str)
          str.to_s.split("/").first.to_i
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
            @categories[cat_name] = category_with_merged_actions(cat_body).freeze
          end
        end

        # @categories and @actions must agree on what an action's config is.
        # Before this fix, @categories[cat]["actions"] held the raw,
        # un-merged action hashes while @actions held the merged-over-defaults
        # ones, so a consumer reading `config.categories[...]["actions"]`
        # instead of `config.action(name)` would see an action missing the
        # keys it actually inherits (security-review follow-up on f-l10-6,
        # PR #73).
        def category_with_merged_actions(cat_body)
          return cat_body unless cat_body.is_a?(Hash)

          merged_actions = Array(cat_body["actions"]).filter_map do |action_hash|
            @actions[action_hash["name"].to_s] if action_hash.is_a?(Hash)
          end
          cat_body.merge("actions" => merged_actions)
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
          # ActionValidator is given the MERGED hash, not the raw action_hash:
          # validating the raw hash let a `defaults` section with an
          # over-ceiling value (e.g. blast_radius_cap above max_blast_radius)
          # load clean, then silently hand every action that omits its own
          # cap an over-ceiling value at enforcement time (security-review
          # follow-up on f-l10-6, PR #73).
          merged = merge_with_defaults(action_hash)
          ActionValidator.new(action_hash, merged, name, @hard_ceilings, @errors).validate
          @actions[name] = merged.freeze
        end

        # `defaults` is required precisely so an action can omit rate_limit,
        # blast_radius_cap, or nonce_ttl_seconds and inherit it here; without
        # this merge RateLimiter/BlastRadiusEnforcer raise NoMethodError/
        # ArgumentError on the missing key at call time instead of denying
        # (finding f-l10-6, review wave 2026-08-25). Explicit per-action keys
        # win over the defaults.
        #
        # Only INHERITABLE_ACTION_KEYS are ever pulled from `defaults`: a
        # stray key in `defaults` (rejected separately by
        # Validator#validate_defaults_known_keys, but this is defense in
        # depth) can never inject into every action via this merge.
        #
        # An action key that is explicitly present but nil (the blank-scalar
        # YAML idiom, e.g. `rate_limit: ~`) is treated as absent, not as an
        # override to nil: without this, an authored blank still won over the
        # default and reached RateLimiter/BlastRadiusEnforcer as nil later
        # (security-review follow-up on f-l10-6, PR #73).
        def merge_with_defaults(action_hash)
          inheritable = @defaults.slice(*INHERITABLE_ACTION_KEYS)
          explicit = action_hash.reject { |key, value| inheritable.key?(key) && value.nil? }
          inheritable.merge(explicit)
        end

        def check_action_name_format(name)
          return if NAME_PATTERN.match?(name)

          @errors << "action name '#{name}' does not match #{NAME_PATTERN.source}"
        end

        def check_action_duplicate(name, cat_name)
          return unless @actions.key?(name)

          @errors << "duplicate action name '#{name}' found again in category '#{cat_name}'"
        end
      end

      # Validates the top-level structure of the policy hash. Defined as its
      # own top-level class (PolicyConfig::Validator, reopened) rather than
      # nested inside PolicyConfig's own body so none of the four validator
      # classes below count toward PolicyConfig's own Metrics/ClassLength;
      # `Validator`/`DefaultsCeilingValidator`/`ActionValidator` still resolve
      # as bare constants from inside PolicyConfig's own methods via normal
      # Ruby lexical constant lookup (security-review follow-up on f-l10-6,
      # PR #73).
      class PolicyConfig::Validator # rubocop:disable Style/ClassAndModuleChildren
        def initialize(raw, errors)
          @raw    = raw
          @errors = errors
        end

        def validate
          validate_version
          validate_section("defaults", PolicyConfig::REQUIRED_DEFAULTS)
          validate_defaults_known_keys
          validate_section("hard_ceilings", PolicyConfig::REQUIRED_CEILINGS)
          validate_section("global_rate_limits", PolicyConfig::REQUIRED_GLOBALS)
          validate_categories_present
          validate_defaults_against_ceilings
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

        # A stray key in `defaults` (e.g. a misplaced `parameters:`) would
        # otherwise load clean and silently be excluded from every action's
        # merge (harmless today because PolicyConfig#merge_with_defaults
        # only pulls INHERITABLE_ACTION_KEYS) or, before that allowlist
        # existed, injected into every action that omits it. Reject it at
        # load so a typo in `defaults` fails loudly instead of either
        # (security-review follow-up on f-l10-6, PR #73).
        def validate_defaults_known_keys
          section = @raw["defaults"]
          return unless section.is_a?(Hash)

          unknown = section.keys - PolicyConfig::REQUIRED_DEFAULTS
          return if unknown.empty?

          @errors << "defaults has unknown key(s): #{unknown.join(", ")} " \
                     "(only #{PolicyConfig::REQUIRED_DEFAULTS.join(", ")} are allowed)"
        end

        # `defaults` feeds every action that omits its own rate_limit,
        # blast_radius_cap, or nonce_ttl_seconds (see PolicyConfig#process_action).
        # Without this check a bad `defaults` section (e.g. blast_radius_cap
        # above max_blast_radius) loaded clean and handed every such action
        # an over-ceiling value at enforcement time instead of failing at
        # load (security-review follow-up on f-l10-6, PR #73).
        def validate_defaults_against_ceilings
          return unless section_complete?("defaults", PolicyConfig::REQUIRED_DEFAULTS) &&
                        section_complete?("hard_ceilings", PolicyConfig::REQUIRED_CEILINGS)

          PolicyConfig::DefaultsCeilingValidator.new(@raw["defaults"], @raw["hard_ceilings"], @errors).validate
        end

        def section_complete?(key, required_fields)
          section = @raw[key]
          section.is_a?(Hash) && required_fields.all? { |f| section.key?(f) }
        end
      end

      # Validates the `defaults` section itself against `hard_ceilings`, so a
      # bad defaults section fails at load instead of silently authorizing an
      # over-ceiling value for every action that omits an explicit cap
      # (security-review follow-up on f-l10-6, PR #73). Reopened as
      # PolicyConfig::DefaultsCeilingValidator for the same Metrics/ClassLength
      # reason as PolicyConfig::Validator above.
      class PolicyConfig::DefaultsCeilingValidator # rubocop:disable Style/ClassAndModuleChildren
        def initialize(defaults, ceilings, errors)
          @defaults = defaults
          @ceilings = ceilings
          @errors   = errors
        end

        def validate
          validate_rate_limit
          validate_blast_radius
          validate_nonce_ttl
        end

        private

        def validate_rate_limit
          rate_limit = @defaults["rate_limit"]
          return unless PolicyConfig::RATE_LIMIT_PATTERN.match?(rate_limit.to_s)

          max    = PolicyConfig.rate_limit_count(@ceilings["max_rate_limit"])
          actual = PolicyConfig.rate_limit_count(rate_limit)
          return if actual <= max

          @errors << "defaults.rate_limit #{rate_limit} exceeds hard ceiling #{@ceilings["max_rate_limit"]}"
        end

        def validate_blast_radius
          cap = @defaults["blast_radius_cap"]
          return unless cap.is_a?(Integer)

          max = @ceilings["max_blast_radius"]
          return if cap <= max

          @errors << "defaults.blast_radius_cap #{cap} exceeds hard ceiling #{max}"
        end

        def validate_nonce_ttl
          ttl = @defaults["nonce_ttl_seconds"]
          return unless ttl.is_a?(Integer)

          min_ttl = @ceilings["min_nonce_ttl_seconds"]
          max_ttl = @ceilings["max_nonce_ttl_seconds"]
          return if ttl.between?(min_ttl, max_ttl)

          @errors << "defaults.nonce_ttl_seconds #{ttl} must be between #{min_ttl} and #{max_ttl}"
        end
      end

      # Validates a single action hash against field, operation, and ceiling
      # rules. Reopened as PolicyConfig::ActionValidator for the same
      # Metrics/ClassLength reason as PolicyConfig::Validator above.
      #
      # `action_hash` (the raw, as-authored action) is used for the
      # required-field and read/mutate confirmation-consistency checks, so an
      # action that omits `requires_confirmation` still fails loudly rather
      # than silently inheriting the defaults value. `merged_action` (action
      # merged over defaults, i.e. what actually reaches RateLimiter and
      # BlastRadiusEnforcer at runtime) is used for the ceiling checks, so an
      # action that inherits its cap from `defaults` is still checked against
      # `hard_ceilings` (security-review follow-up on f-l10-6, PR #73).
      class PolicyConfig::ActionValidator # rubocop:disable Style/ClassAndModuleChildren
        def initialize(action_hash, merged_action, name, ceilings, errors)
          @action   = action_hash
          @merged   = merged_action
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

          @errors << "action '#{@name}' operation '#{op}' must be one of: #{PolicyConfig::VALID_OPERATIONS.join(", ")}"
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
          rl = @merged["rate_limit"]
          return unless rl

          unless PolicyConfig::RATE_LIMIT_PATTERN.match?(rl.to_s)
            @errors << "action '#{@name}' rate_limit '#{rl}' must match format N/minute"
            return
          end
          check_rate_limit_ceiling(rl)
        end

        def check_rate_limit_ceiling(rate_limit)
          max    = PolicyConfig.rate_limit_count(@ceilings["max_rate_limit"])
          actual = PolicyConfig.rate_limit_count(rate_limit)
          return if actual <= max

          @errors << "action '#{@name}' rate_limit #{rate_limit} exceeds hard ceiling #{@ceilings["max_rate_limit"]}"
        end

        def validate_blast_radius
          cap = @merged["blast_radius_cap"]
          return unless cap.is_a?(Integer)

          max = @ceilings["max_blast_radius"]
          return if cap <= max

          @errors << "action '#{@name}' blast_radius_cap #{cap} exceeds hard ceiling #{max}"
        end

        def validate_nonce_ttl
          ttl = @merged["nonce_ttl_seconds"]
          return unless ttl.is_a?(Integer)

          min_ttl = @ceilings["min_nonce_ttl_seconds"]
          max_ttl = @ceilings["max_nonce_ttl_seconds"]
          return if ttl.between?(min_ttl, max_ttl)

          @errors << "action '#{@name}' nonce_ttl_seconds #{ttl} must be between #{min_ttl} and #{max_ttl}"
        end
      end
    end
  end
end
