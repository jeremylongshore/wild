# frozen_string_literal: true

require "yaml"

module Wild
  module CapabilityGate
    module Audit
      # Validates an audit event hash against the published JSON Schema
      # (`lib/wild/schemas/capability_gate/audit_event.yml`, draft 2020-12) at
      # emit time (F2, wild-rvv.4.1.2).
      #
      # Pairs with the test-time round-trip conformance spec (wild-rvv.4.1.3):
      # that spec proves representative events conform; this validator proves
      # EVERY event emitted during a dev/test run conforms, catching shapes the
      # representative samples miss.
      #
      # Gem: json_schemer (draft 2020-12). It is a DEVELOPMENT dependency — audit
      # validation defaults on in dev/test, off in prod. A prod consumer that
      # opts in must add json_schemer to their own bundle; #validate! raises a
      # clear ConfigurationError if validation is requested but the gem is absent
      # rather than silently skipping (a silently-skipped validator is a lie).
      module SchemaValidator
        SCHEMA_PATH = File.expand_path(
          "../../schemas/capability_gate/audit_event.yml", __dir__
        )

        class << self
          # Whether emitted audit events should be validated. Reads the live
          # config so tests can flip it per-example. `:auto` (default) → on in
          # dev/test, off in prod (validation costs; a non-conforming event is a
          # developer bug we want surfaced in dev/test, not in production).
          # `true`/`false` force the behaviour regardless of environment.
          def enabled?
            case Wild.config.capability_gate.validate_audit_events
            when true then true
            when false then false
            else %i[development test].include?(Wild.config.environment)
            end
          end

          # Raise Wild::CapabilityGate::AuditSchemaError if `event_hash` does not
          # conform. Returns nil on success. Never call this on the prod hot path
          # unless validation is explicitly enabled — compiling/validating costs.
          def validate!(event_hash)
            errors = schemer.validate(event_hash).map { |e| describe(e) }
            return if errors.empty?

            raise Wild::CapabilityGate::AuditSchemaError,
                  "audit event does not conform to audit_event.yml: #{errors.join("; ")}"
          end

          # rubocop:disable Rails/Delegate -- class-method facade over a memoized private helper, not an instance delegation
          def valid?(event_hash)
            schemer.valid?(event_hash)
          end
          # rubocop:enable Rails/Delegate

          # Reset the memoized schemer (test support — after a schema edit).
          def reset!
            @schemer = nil
          end

          private

          # Compiled schema, memoized — compilation is the expensive step.
          def schemer
            @schemer ||= begin
              require "json_schemer"
              JSONSchemer.schema(YAML.safe_load_file(SCHEMA_PATH, permitted_classes: []))
            rescue LoadError
              raise Wild::ConfigurationError,
                    "audit-event validation is enabled but the `json_schemer` gem is not available. " \
                    "Add `gem \"json_schemer\"` to your bundle, or disable validation via " \
                    "`Wild.config.capability_gate.validate_audit_events = false`."
            end
          end

          # Compact, greppable one-liner per validation error.
          def describe(error)
            pointer = error["data_pointer"].to_s
            loc = pointer.empty? ? "(root)" : pointer
            "#{loc} #{error["type"]}"
          end
        end
      end
    end
  end
end
