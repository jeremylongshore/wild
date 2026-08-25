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
          # Wild.config.audit_logger (at :error, mirroring
          # CapabilityGate::Evaluator#log_audit_failure exactly) when one is
          # configured, never raise out of the logging path itself.
          #
          # #store_envelope distinguishes two failure shapes: a
          # Wild::Telemetry::Collector::StorageError (a real store I/O
          # failure, now raised by JsonLinesStore's own append/compact/
          # clear!) increments #storage_failure_count and logs as a storage
          # failure; any other StandardError (a bug in a custom store, or in
          # the store adapter itself) is logged separately as an internal
          # error and does not inflate the storage-failure counter, so an
          # operator alerting on that counter is alerting on genuine
          # disk/IO problems, not on arbitrary store bugs.
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
          rescue StorageError => e
            record_storage_failure(e)
            nil
          rescue StandardError => e
            record_internal_error(e)
            nil
          end

          def record_storage_failure(error)
            @counter_mutex.synchronize { @storage_failure_count += 1 }
            log_storage_failure(error)
          end

          def record_internal_error(error)
            log_internal_error(error)
          end

          def log_storage_failure(error)
            logger = Wild.config.audit_logger
            return unless logger.respond_to?(:error)

            logger.error(
              "[wild:telemetry:collector] event store append failed: " \
              "#{error.class}: #{safe_message(error)} (event dropped, fire-and-forget)"
            )
          rescue StandardError
            # The configured logger is itself broken. There is nowhere left
            # to record this; the counter above already made the failure
            # observable without depending on the logger working.
            nil
          end

          def log_internal_error(error)
            logger = Wild.config.audit_logger
            return unless logger.respond_to?(:error)

            logger.error(
              "[wild:telemetry:collector] unexpected internal error while storing event: " \
              "#{error.class}: #{safe_message(error)} (event dropped, fire-and-forget)"
            )
          rescue StandardError
            # Same rationale as #log_storage_failure: a broken logger has
            # nowhere left to record this, and there is no counter to fall
            # back on for internal errors, but re-raising here would turn a
            # should-have-been-caught error into an uncaught one.
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
