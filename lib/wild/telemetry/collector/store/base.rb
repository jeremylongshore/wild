# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Store
        class Base
          def append(envelope)
            raise NotImplementedError, "#{self.class}#append must be implemented"
          end

          def recent(limit: 50)
            raise NotImplementedError, "#{self.class}#recent must be implemented"
          end

          def find(timestamp:, event_type:)
            raise NotImplementedError, "#{self.class}#find must be implemented"
          end

          def count
            raise NotImplementedError, "#{self.class}#count must be implemented"
          end

          def query(event_type: nil, since: nil, before: nil)
            raise NotImplementedError, "#{self.class}#query must be implemented"
          end

          def clear!
            raise NotImplementedError, "#{self.class}#clear! must be implemented"
          end
        end
      end
    end
  end
end
