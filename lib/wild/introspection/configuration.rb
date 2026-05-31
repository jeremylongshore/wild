# frozen_string_literal: true

require "yaml"

module Wild
  module Introspection
    class Configuration # rubocop:disable Metrics/ClassLength
      CONSTANT_NAME_PATTERN = /\A[A-Z][A-Za-z0-9]*(::[A-Z][A-Za-z0-9]*)*\z/
      HARD_ROW_CEILING = 1000
      HARD_TIMEOUT_CEILING_MS = 30_000
      MINIMUM_TIMEOUT_MS = 100

      attr_accessor :access_policy_path, :blocked_resources_path, :audit_log_path, :api_keys
      attr_reader :defaults, :model_registry, :blocked_models, :blocked_columns

      def initialize
        @access_policy_path = nil
        @blocked_resources_path = nil
        @audit_log_path = nil
        @api_keys = []
        @defaults = { "max_rows" => 50, "query_timeout_ms" => 5000 }
        @model_registry = {}
        @blocked_models = []
        @blocked_columns = []
      end

      def load!
        validate_paths!
        load_access_policy!
        load_blocked_resources!
        clamp_hard_ceilings!
        build_model_registry!
        freeze_policy_data!
      end

      def resolve_model(name)
        @model_registry[name]&.fetch(:klass, nil)
      end

      def model_allowed?(name)
        @model_registry.key?(name)
      end

      def model_config(name)
        @model_registry[name]
      end

      def blocked_columns_for(model_name)
        applicable = @blocked_columns.select { |entry| [model_name, "*"].include?(entry["model"]) }
        applicable.flat_map { |entry| entry["columns"] || [] }.uniq
      end

      private

      def validate_paths!
        raise ConfigError, "access_policy_path is required" unless @access_policy_path
        raise ConfigError, "blocked_resources_path is required" unless @blocked_resources_path

        [[@access_policy_path, "access_policy"], [@blocked_resources_path, "blocked_resources"]].each do |path, label|
          raise ConfigError, "#{label} not found: #{path}" unless File.exist?(path)
        end
      end

      def load_access_policy!
        data = YAML.safe_load_file(@access_policy_path)
        raise ConfigError, "access_policy.yml must contain a version field" unless data&.key?("version")

        @defaults = @defaults.merge(data["defaults"] || {})
        @allowed_models_config = data["allowed_models"] || []
      end

      def load_blocked_resources!
        data = YAML.safe_load_file(@blocked_resources_path)
        raise ConfigError, "blocked_resources.yml must contain a version field" unless data&.key?("version")

        @blocked_models = (data["blocked_models"] || []).freeze
        @blocked_columns = (data["blocked_columns"] || []).freeze
      end

      def clamp_hard_ceilings!
        @defaults["max_rows"] = @defaults["max_rows"].clamp(1, HARD_ROW_CEILING)
        @defaults["query_timeout_ms"] = @defaults["query_timeout_ms"].clamp(MINIMUM_TIMEOUT_MS, HARD_TIMEOUT_CEILING_MS)
      end

      def build_model_registry!
        @model_registry = {}
        @allowed_models_config.each do |entry|
          name = entry["name"]
          next if @blocked_models.include?(name)

          klass = safe_resolve_constant(name)
          @model_registry[name] = build_model_entry(klass, entry) if klass
        end
      end

      def build_model_entry(klass, model_entry)
        max_rows = model_entry["max_rows"] || @defaults["max_rows"]
        timeout_ms = model_entry["query_timeout_ms"] || @defaults["query_timeout_ms"]

        {
          klass: klass,
          columns_mode: resolve_columns_mode(model_entry["columns"]),
          explicit_columns: resolve_explicit_columns(model_entry["columns"]),
          max_rows: max_rows.clamp(1, HARD_ROW_CEILING),
          query_timeout_ms: timeout_ms.clamp(MINIMUM_TIMEOUT_MS, HARD_TIMEOUT_CEILING_MS)
        }
      end

      def safe_resolve_constant(name)
        return nil unless name.is_a?(String) && name.match?(CONSTANT_NAME_PATTERN)

        Object.const_get(name)
      rescue NameError
        nil
      end

      def resolve_columns_mode(columns)
        case columns
        when "all" then :all
        when Array then :explicit
        else :all_except_blocked
        end
      end

      def resolve_explicit_columns(columns)
        columns.is_a?(Array) ? columns.map(&:to_s) : nil
      end

      def freeze_policy_data!
        @defaults.freeze
        @model_registry.each_value(&:freeze)
        @model_registry.freeze
      end
    end
  end
end
