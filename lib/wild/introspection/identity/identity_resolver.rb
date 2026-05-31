# frozen_string_literal: true

require "active_support/security_utils"

module Wild
  module Introspection
    module Identity
      module IdentityResolver
        def self.resolve(api_key:)
          return RequestContext.anonymous if api_key.nil? || api_key.to_s.empty?

          entry = find_api_key(api_key)
          unless entry
            return RequestContext.new(
              caller_id: "unknown", caller_type: "api_key", auth_result: :invalid
            )
          end

          RequestContext.new(
            caller_id: entry[:name], caller_type: "api_key", auth_result: :success
          )
        end

        def self.find_api_key(key)
          Wild::Introspection.configuration.api_keys.find do |entry|
            ActiveSupport::SecurityUtils.secure_compare(entry[:key].to_s, key.to_s)
          end
        end
        private_class_method :find_api_key
      end
    end
  end
end
