# frozen_string_literal: true

module Wild
  module AdminTools
    module Executor
      module Adapters
        class FlagAdapter
          # Read methods (no side effects)
          def read_flag(_flag_name)
            raise NotImplementedError, "#{self.class}#read_flag"
          end

          def list_flags(**_options)
            raise NotImplementedError, "#{self.class}#list_flags"
          end

          # Write methods (mutating — suffixed with !)
          def toggle_flag!(_flag_name, _enabled)
            raise NotImplementedError, "#{self.class}#toggle_flag!"
          end

          def enable_for_actor!(_flag_name, _actor_type, _actor_id)
            raise NotImplementedError, "#{self.class}#enable_for_actor!"
          end

          def disable_for_actor!(_flag_name, _actor_type, _actor_id)
            raise NotImplementedError, "#{self.class}#disable_for_actor!"
          end

          def enable_percentage!(_flag_name, _percentage)
            raise NotImplementedError, "#{self.class}#enable_percentage!"
          end

          def delete_flag!(_flag_name)
            raise NotImplementedError, "#{self.class}#delete_flag!"
          end
        end
      end
    end
  end
end
