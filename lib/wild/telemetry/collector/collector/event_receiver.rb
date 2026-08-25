# frozen_string_literal: true

module Wild
  module Telemetry
    module Collector
      module Collector
        class EventReceiver
          # Fire-and-forget: #receive returns nil on both a schema rejection
          # and a store failure (spec-pinned in
          # spec/.../adversarial/safety_rules_spec.rb Rule 5 and
          # event_receiver_spec.rb "fire-and-forget: store raises"). That
          # contract stays. What was missing (finding f-l02-3) is that a
          # store failure (ENOSPC, EACCES, EIO) was indistinguishable from an
          # ordinary validation reject: both fell into the same bare `rescue
          # StandardError; nil`, with nothing recorded anywhere. This class
          # now counts and logs store failures distinctly, following the F2
          # "not doubly silent" pattern already established in
          # Wild::CapabilityGate::Evaluator#log_audit_failure: log to
          # Wild.config.audit_logger when one is configured, never raise out
          # of the logging path itself.
          attr_reader :storage_failure_count

          def initialize(store:, validator: nil, filter: nil)
            @store = store
            @validator = validator || Schema::Validator.new
            @filter = filter || Privacy::Filter.new
            @storage_failure_count = 0
            @counter_mutex = Mutex.new
          end

          def receive(event)
            filtered = @filter.filter(event)
            valid, _errors = @validator.validate(filtered)
            return nil unless valid

            envelope = Schema::EventEnvelope.from_raw(filtered)
            store_envelope(envelope)
          rescue StandardError
            nil
          end

          private

          def store_envelope(envelope)
            @store.append(envelope)
            envelope
          rescue StandardError => e
            record_storage_failure(e)
            nil
          end

          def record_storage_failure(error)
            @counter_mutex.synchronize { @storage_failure_count += 1 }
            log_storage_failure(error)
          end

          def log_storage_failure(error)
            logger = Wild.config.audit_logger
            return unless logger.respond_to?(:warn)

            logger.warn(
              "[wild:telemetry:collector] event store append failed: " \
              "#{error.class}: #{safe_message(error)} (event dropped, fire-and-forget)"
            )
          rescue StandardError
            # The configured logger is itself broken. There is nowhere left
            # to record this; the counter above already made the failure
            # observable without depending on the logger working.
            nil
          end

          # #message on an arbitrary rescued exception is not guaranteed safe
          # (mirrors Wild::CapabilityGate::Evaluator#safe_message).
          def safe_message(error)
            error.message
          rescue StandardError
            "<unprintable message>"
          end
        end
      end
    end
  end
end
