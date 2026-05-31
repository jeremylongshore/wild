# frozen_string_literal: true

module Wild
  module AdminTools
    class Configuration
      attr_accessor :job_adapter, :cache_adapter, :flag_adapter, :policy_path,
                    :audit_store, :audit_log_path, :gate

      def initialize
        @job_adapter = nil
        @cache_adapter = nil
        @flag_adapter = nil
        @policy_path = nil
        @audit_store = nil
        @audit_log_path = nil
        @gate = nil
      end

      def validate!
        errors = []
        errors << "job_adapter is required" if @job_adapter.nil?
        errors << "cache_adapter is required" if @cache_adapter.nil?
        errors << "flag_adapter is required" if @flag_adapter.nil?
        raise ConfigurationError, errors.join(", ") unless errors.empty?
      end
    end
  end
end
