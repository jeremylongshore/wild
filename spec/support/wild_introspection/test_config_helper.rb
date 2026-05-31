# frozen_string_literal: true

module Wild
  module Introspection
    module TestSupport
      module TestConfigHelper
        FIXTURES_PATH = File.expand_path("fixtures", __dir__)
        TEST_API_KEY = "sk-test-valid-key"

        def configure_with_test_fixtures!
          Wild::Introspection.configure do |config|
            config.access_policy_path = File.join(FIXTURES_PATH, "access_policy.yml")
            config.blocked_resources_path = File.join(FIXTURES_PATH, "blocked_resources.yml")
          end
          Wild::Introspection.configuration.api_keys = [
            { key: TEST_API_KEY, name: "test-agent" }
          ]
        end

        def authenticated_context
          Wild::Introspection::Identity::RequestContext.new(
            caller_id: "test-agent", caller_type: "api_key", auth_result: :success
          )
        end

        def anonymous_context
          Wild::Introspection::Identity::RequestContext.anonymous
        end

        def authenticated_server_context
          { api_key: TEST_API_KEY }
        end
      end
    end
  end
end
