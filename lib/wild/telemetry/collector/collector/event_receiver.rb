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
          attr_reader :storage_monitor

          delegate :storage_failure_count, to: :storage_monitor

          def initialize(store:, validator: nil, filter: nil, storage_monitor: nil)
            @store = store
            @validator = validator || Schema::Validator.new
            @filter = filter || Privacy::Filter.new
            @storage_monitor = storage_monitor || Store::StorageMonitor.new(store: store)
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
            @storage_monitor.record_storage_failure(error)
            log_storage_failure(error)
          end

          def record_internal_error(error)
            log_internal_error(error)
          end

          def log_storage_failure(error)
            Wild::AuditFailureLog.record(
              tag: "telemetry:collector",
              error: error,
              detail: "event store append failed (event dropped, fire-and-forget)"
            )
          end

          def log_internal_error(error)
            Wild::AuditFailureLog.record(
              tag: "telemetry:collector",
              error: error,
              detail: "unexpected internal error while storing event (event dropped, fire-and-forget)"
            )
          end
        end
      end
    end
  end
end
