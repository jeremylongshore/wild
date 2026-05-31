# frozen_string_literal: true

module Wild
  module Introspection
    module Identity
      class RequestContext
        attr_reader :caller_id, :caller_type, :auth_result

        def initialize(caller_id:, caller_type:, auth_result:)
          @caller_id = caller_id
          @caller_type = caller_type
          @auth_result = auth_result
          freeze
        end

        def authenticated?
          @auth_result == :success
        end

        def self.anonymous
          new(caller_id: "anonymous", caller_type: "unknown", auth_result: :rejected)
        end
      end
    end
  end
end
