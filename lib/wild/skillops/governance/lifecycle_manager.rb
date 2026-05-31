# frozen_string_literal: true

module Wild
  module Skillops
    module Governance
      # Enforces valid lifecycle state transitions for skills.
      #
      # Permitted transitions:
      #   draft      -> active, retired
      #   active     -> deprecated
      #   deprecated -> retired
      #   retired    -> (terminal — no further transitions)
      LIFECYCLE_TRANSITIONS = {
        draft: %i[active retired],
        active: %i[deprecated],
        deprecated: %i[retired],
        retired: []
      }.freeze

      class LifecycleManager
        # Raises LifecycleError if the transition from current to target is not allowed.
        # Returns target on success.
        def transition!(current, target)
          current_sym = current.to_sym
          target_sym  = target.to_sym

          allowed = allowed_transitions(current_sym)
          unless allowed.include?(target_sym)
            raise LifecycleError,
                  "Cannot transition from '#{current_sym}' to '#{target_sym}'. " \
                  "Allowed transitions: #{allowed.inspect}"
          end

          target_sym
        end

        def allowed_transitions(state)
          LIFECYCLE_TRANSITIONS.fetch(state.to_sym, [])
        end

        def terminal?(state)
          LIFECYCLE_TRANSITIONS.fetch(state.to_sym, []).empty?
        end
      end
    end
  end
end
