# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Collector
        class EventReceiver
          def initialize(store:, validator: nil, filter: nil)
            @store = store
            @validator = validator || Schema::Validator.new
            @filter = filter || Privacy::Filter.new
          end

          def receive(event)
            filtered = @filter.filter(event)
            valid, _errors = @validator.validate(filtered)
            return nil unless valid

            envelope = Schema::EventEnvelope.from_raw(filtered)
            @store.append(envelope)
            envelope
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
