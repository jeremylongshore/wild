# frozen_string_literal: true

module Wild
  module AdminTools
    module Guard
      class ActionAllowlist
        def initialize(policy_config)
          @policy = policy_config
        end

        def allowed?(action_name)
          !@policy.action(action_name.to_s).nil?
        end

        def action_config(action_name)
          @policy.action(action_name.to_s)
        end

        def all_action_names
          @policy.actions.keys.freeze
        end

        def operation_for(action_name)
          action_config(action_name)&.fetch("operation", nil)
        end

        def check!(action_name)
          return if allowed?(action_name)

          raise ActionNotFoundError, action_name.to_s
        end
      end
    end
  end
end
